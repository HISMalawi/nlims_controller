# frozen_string_literal: true

require "tailwindcss/commands"

# The layout links the compiled stylesheet, and Propshaft raises rather than
# serving an asset that is not there — so every request spec that renders a page
# would fail on a clean checkout. `assets:precompile` builds it in the image and
# `bin/dev` watches it in development; neither runs before rspec.
#
# Built once per run, and only when it is missing: the file is gitignored, and
# whether it is a few classes out of date has no bearing on what a request spec
# asserts.
build = Rails.root.join("app/assets/builds/tailwind.css")

unless build.exist?
  build.dirname.mkpath
  system(*Tailwindcss::Commands.compile_command, exception: true)
end
