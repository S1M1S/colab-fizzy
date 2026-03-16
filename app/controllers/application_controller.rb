class ApplicationController < ActionController::Base
  include Authentication
  include Authorization
  include BlockSearchEngineIndexing
  include CurrentRequest, CurrentTimezone, SetPlatform
  include RequestForgeryProtection
  include TurboFlash, ViewTransitions
  include RoutingHeaders

  # HACK:
  skip_before_action :verify_authenticity_token if Rails.env.local?

  etag { "v1" }
  stale_when_importmap_changes
  allow_browser versions: :modern
end
