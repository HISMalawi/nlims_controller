# frozen_string_literal: true

# The handful of shapes every screen is made of. Written as helpers rather than
# repeated class strings so that a status badge means the same colour on the
# dashboard, in the order history and in the sync queue — an operator learns the
# colours once.
module UiHelper
  TONES = {
    neutral: "bg-slate-100 text-slate-700 ring-slate-500/20",
    good: "bg-emerald-50 text-emerald-800 ring-emerald-600/20",
    working: "bg-sky-50 text-sky-800 ring-sky-600/20",
    waiting: "bg-amber-50 text-amber-900 ring-amber-600/30",
    bad: "bg-rose-50 text-rose-800 ring-rose-600/20"
  }.freeze

  # The state machines' vocabularies, mapped onto those five colours. A status
  # this does not know is grey rather than missing: adding a state to a machine
  # should not blank out a column.
  STATUS_TONES = {
    "requested" => :neutral, "accepted" => :working, "specimen_collected" => :working,
    "in_progress" => :working, "referred_out" => :waiting, "referred_in" => :waiting,
    "completed" => :good, "rejected" => :bad, "cancelled" => :neutral,
    "pending" => :neutral, "resulted" => :good, "verified" => :good,
    "dispatched" => :waiting, "received" => :good,
    "draft" => :neutral, "active" => :good, "retired" => :neutral
  }.freeze

  def badge(text, tone: :neutral)
    tag.span(text, class: "inline-flex items-center rounded-md px-2 py-0.5 text-xs font-medium " \
                          "ring-1 ring-inset #{TONES.fetch(tone, TONES[:neutral])}")
  end

  def status_badge(status, scope:)
    badge(t("#{scope}.#{status}", default: status.to_s.humanize), tone: STATUS_TONES.fetch(status.to_s, :neutral))
  end

  def panel(title = nil, subtitle: nil, actions: nil, &block)
    render "shared/panel", title: title, subtitle: subtitle, actions: actions, body: capture(&block)
  end

  # One number and what it counts. `tone` is for the numbers that mean something
  # is wrong — a backlog, a node not heard from — so they are visible from the
  # doorway rather than requiring the label to be read.
  def stat(label, value, tone: :neutral, hint: nil)
    render "shared/stat", label: label, value: value, tone: tone, hint: hint
  end

  # Times are shown as both the clock and the distance from now: "há 3 minutos"
  # is what tells an operator the link is alive, and the timestamp is what goes
  # in the incident report.
  def timestamp(time, blank: "—")
    return tag.span(blank, class: "text-slate-400") if time.blank?

    tag.time(l(time, format: :short),
             datetime: time.iso8601,
             title: l(time, format: :long),
             class: "tabular whitespace-nowrap")
  end

  def time_ago(time, blank: "—")
    return tag.span(blank, class: "text-slate-400") if time.blank?

    tag.span(t("time_ago", distance: time_ago_in_words(time)),
             title: l(time, format: :long),
             class: "whitespace-nowrap")
  end

  # A duration in words, for the transport time of a referred sample and the age
  # of the oldest event still in the outbox.
  def duration(seconds, blank: "—")
    return tag.span(blank, class: "text-slate-400") if seconds.blank?

    tag.span(distance_of_time_in_words(seconds), class: "whitespace-nowrap")
  end

  def mono(value, blank: "—")
    return tag.span(blank, class: "text-slate-400") if value.blank?

    tag.span(value, class: "font-mono text-sm tabular")
  end
end
