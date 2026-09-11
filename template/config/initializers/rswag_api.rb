Rswag::Api.configure do |c|
  # Specify a root folder where Swagger JSON files are located
  # This is used by the Swagger middleware to serve requests for API descriptions
  # NOTE: If you're using rswag-specs to generate Swagger, you'll need to ensure
  # that it's configured to generate files in the same folder
  c.openapi_root = Rails.root.to_s + "/swagger"

  # Inject a lambda function to alter the returned Swagger prior to serialization
  # The function will have access to the rack env for the current request
  # Here we use it to point the "servers" entry at whatever host/scheme the doc
  # was actually requested through, so Swagger UI "Try it out" works against
  # dev, staging or production without hardcoding a host in swagger.yaml.
  c.swagger_filter = lambda do |swagger, env|
    request = Rack::Request.new(env)
    swagger["servers"] = [ { "url" => "#{request.scheme}://#{request.host_with_port}" } ]
  end
end
