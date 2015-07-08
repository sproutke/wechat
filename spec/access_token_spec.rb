require 'spec_helper'

describe Wechat::AccessToken do
  let(:app_id){'app_id'}
  let(:secret){'secret'}
  let(:redis){Redis.new}

  before do
    stub_request(:get, "#{Wechat::AccessToken::ACCESS_TOKEN_URL}?appid=#{app_id}&grant_type=client_credential&secret=#{secret}").
      to_return(:status => 200, :body => { "access_token" => "token", "expires_in" => 7200}.to_json, :headers => {})
    end

  context 'get a new access code' do
    subject {
      Wechat::AccessToken.new(app_id, secret)
    }
    it do
      expect(subject.access_token).to eql('token')
      expect(JSON.parse(redis.get(app_id))['access_token']).to eql('token')
      expect(JSON.parse(redis.get(app_id))['expires_in']).to eql(7200)
      expect(JSON.parse(redis.get(app_id))['new_token_requested']).to eql(false)
   end
  end

  describe 'if token is valid for more than 5 minutes' do
    before do
      hash = Hash['access_token','token1','expires_in',7200, 'time_stamp', Time.now.to_i, 'new_token_requested', false]
      redis.set app_id, hash.to_json
    end

    context 'return a cached access_token' do
      subject {
        Wechat::AccessToken.new(app_id, secret)
      }
      it do
        expect(subject.access_token).to eql('token1')
        expect(JSON.parse(redis.get(app_id))['access_token']).to eql('token1')
        expect(JSON.parse(redis.get(app_id))['expires_in']).to eql(7200)
        expect(JSON.parse(redis.get(app_id))['new_token_requested']).to eql(false)
     end
    end
  end

  describe 'if token is valid for less than 5 minutes' do
    before do
      hash = Hash['access_token','token1','expires_in',7200, 'time_stamp', (Time.now - 6960).to_i, 'new_token_requested', false]
      redis.set app_id, hash.to_json
    end

    context 'return cached access_token and fetch new one' do
      subject {
        Wechat::AccessToken.new(app_id, secret)
      }

      it do
        expect(subject.access_token).to eql('token1') #old access_token
        expect(JSON.parse(redis.get(app_id))['access_token']).to eql('token') #new access_token
        expect(JSON.parse(redis.get(app_id))['expires_in']).to eql(7200)
        expect(JSON.parse(redis.get(app_id))['new_token_requested']).to eql(false)
     end
    end
  end

  describe 'if token has expired' do
    before do
      hash = Hash['access_token','token1','expires_in',7200, 'time_stamp', (Time.now - 7205).to_i, 'new_token_requested', false]
      redis.set app_id, hash.to_json
    end

    context 'fetch and return a new access token' do
      subject {
        Wechat::AccessToken.new(app_id, secret)
      }
      it do
        expect(subject.access_token).to eql('token')
        expect(JSON.parse(redis.get(app_id))['access_token']).to eql('token')
        expect(JSON.parse(redis.get(app_id))['expires_in']).to eql(7200)
        expect(JSON.parse(redis.get(app_id))['new_token_requested']).to eql(false)
     end
    end
  end
end
