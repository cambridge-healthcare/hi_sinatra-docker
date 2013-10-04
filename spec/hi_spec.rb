require 'spec_helper'

require_relative '../hi'

describe 'Hi' do
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  describe 'GET /' do
    before { get '/' }

    it "greets us" do
      expect(last_response.body).to include(
        'I am a Sinatra app running inside a docker container'
      )
    end

    it "keeps track of requests" do
      expect(last_response.body).to match(
        /I have been requested \d+ times/
      )
    end
  end
end
