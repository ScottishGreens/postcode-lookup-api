class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception

  def postcodes
    postcode = params[:postcode].gsub(' ', '').upcase
    res = PostcodeLookupService.lookup(postcode)
    render json: res.to_json
  end
end
