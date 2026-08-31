# The interface has to work in a district laboratory on a bad line, so nothing
# is fetched from a CDN at page load: Turbo and Stimulus are served from the
# gems' own asset paths, and the application's own modules from app/javascript.

pin "application"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin_all_from "app/javascript/controllers", under: "controllers"
