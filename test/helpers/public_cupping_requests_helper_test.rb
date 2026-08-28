require "test_helper"

class PublicCuppingRequestsHelperTest < ActionView::TestCase
  test "countdown deadline is emitted as an exact browser millisecond timestamp" do
    request = cupping_requests(:guest_espresso)
    deadline = Time.zone.parse("2026-08-30 12:34:56.789")
    request.feedback_expires_at = deadline

    assert_equal (deadline.to_f * 1000).round, cupping_countdown_deadline_value(request)
  end

  test "countdown text is clamped and formatted as hours minutes and seconds" do
    assert_equal "24:00:00", cupping_countdown_text(24.hours)
    assert_equal "01:02:03", cupping_countdown_text(1.hour + 2.minutes + 3.seconds)
    assert_equal "00:00:00", cupping_countdown_text(-1.second)
  end

  test "taste options provide explicit localized unknown and five-position choices" do
    I18n.with_locale(:en) do
      assert_equal [ "unknown", "very_sour", "sour", "neutral", "bitter", "very_bitter" ],
        cupping_taste_options.map(&:first)
      assert_equal "Not sure yet", cupping_taste_options.first.last
      assert_equal "Very bitter", cupping_taste_options.last.last
    end

    I18n.with_locale(:de) do
      assert_equal "Noch unsicher", cupping_taste_options.first.last
      assert_equal "Sehr bitter", cupping_taste_options.last.last
    end
  end

  test "public Hero taste labels are localized without reading a live Brew" do
    I18n.with_locale(:en) { assert_equal "Neutral", public_snapshot_taste_label("neutral") }
    I18n.with_locale(:de) { assert_equal "Ausgewogen", public_snapshot_taste_label("neutral") }
  end
end
