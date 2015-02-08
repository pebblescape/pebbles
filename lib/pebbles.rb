require "pebbles/version"

module Pebbles
  @@app_name = nil

  USER_AGENT = "pebbles-gem/#{Pebbles::VERSION} (#{RUBY_PLATFORM}) ruby/#{RUBY_VERSION}"

  def self.user_agent
    @@user_agent ||= USER_AGENT
  end

  def self.user_agent=(agent)
    @@user_agent = agent
  end

  def self.app_name
    @@app_name
  end

  def self.app_name=(app_name)
    @@app_name = app_name
  end
end
