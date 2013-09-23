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
      expect(last_response.body).to eq(
        'Hi, I am a Sinatra app running inside a docker container'
      )
    end
  end
end
