require "application_system_test_case"

# Autoplay is a Stimulus controller bound to ReActionView states. These walk
# between pages the way Turbo does, which used to leave it bound to the page
# that was left, or revive `playing` from Turbo's snapshot of a page.
class AutoplayTest < ApplicationSystemTestCase
  setup do
    @network = Network.create!(name: "十字路")
    center = @network.nodes.create!(x: 30, y: 30, signalized: true)
    @network.connect(@network.nodes.create!(x: 0, y: 30), center)
    @network.connect(@network.nodes.create!(x: 60, y: 30), center)
  end

  test "plays on the next page after playing on the previous one" do
    visit network_path(@network)
    click_on "再生"
    assert_button "停止"

    click_on "Intersection"
    assert_selector "h1", text: "Intersection"
    assert_button "再生"
    assert_arrived_stopped

    click_on "再生"
    assert_button "停止"
    assert_selector ".traffic__stats dd", text: /\A[1-9]\d*\z/
  end

  test "plays again on a page visited before" do
    visit intersection_path
    click_on "再生"
    assert_button "停止"

    click_on "Ring Road"
    assert_selector "h1", text: "Ring Road"
    click_on "Intersection"
    assert_selector "h1", text: "Intersection"
    assert_button "再生"
    assert_arrived_stopped

    click_on "再生"
    assert_button "停止"
    assert_selector ".traffic__stats dd", text: /\A[1-9]\d*\z/
  end

  private
    # A page that was just reached must not be playing, neither its timer nor its state
    def assert_arrived_stopped
      sleep 0.3 # let the controller bind
      timer, playing = page.evaluate_script(<<~JS)
        (() => {
          const element = document.querySelector("[data-controller~=autoplay]")
          const controller = window.Stimulus.getControllerForElementAndIdentifier(element, "autoplay")
          return [controller.timer != null, controller.state ? controller.state.get("playing") : null]
        })()
      JS

      assert_not timer, "the autoplay timer is already running"
      assert_not playing, "the page arrived with playing already true"
    end
end
