# frozen_string_literal: true

# One signed-in browser.
#
# The row is the session; the cookie only carries its id, signed. Keeping the
# session server-side is what makes signing out — or being signed out — actually
# take effect, which a self-contained cookie cannot do.
class Session < ApplicationRecord
  # Interface machines sit on open benches and get walked away from. A shift is
  # long, so the window is generous, but it is not indefinite.
  IDLE_TIMEOUT = 12.hours

  # Writing last_seen_at on every page view would turn each read into a write
  # for no gain: the timeout is measured in hours.
  LAST_SEEN_RESOLUTION = 5.minutes

  belongs_to :user

  scope :live, ->(now = Time.current) { where(last_seen_at: (now - IDLE_TIMEOUT)..) }

  def self.start!(user:, ip:, user_agent:)
    create!(user: user, ip: ip, user_agent: user_agent.to_s.truncate(255), last_seen_at: Time.current)
  end

  # Sessions are only ever looked up by a browser presenting one, so the ones
  # nobody comes back for are cleared out on the way past rather than by a job.
  def self.sweep(now: Time.current)
    where(last_seen_at: ...(now - IDLE_TIMEOUT)).delete_all
  end

  def expired?(now = Time.current)
    last_seen_at < now - IDLE_TIMEOUT
  end

  def touch_last_seen!(now: Time.current)
    return if last_seen_at > now - LAST_SEEN_RESOLUTION

    update_column(:last_seen_at, now)
  end
end
