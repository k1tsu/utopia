
require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:test) do |task|
	task.rspec_opts = %w{--require simplecov} if ENV['COVERAGE']
end

task :coverage do
	ENV['COVERAGE'] = 'y'
end

desc 'Start the development environment which includes web server and tests.'
task :development => :environment do
	# This generates a consistent session secret if one was not already provided:
	if ENV['UTOPIA_SESSION_SECRET'].nil?
		require 'securerandom'
		
		warn 'Generating transient session key for development...'
		ENV['UTOPIA_SESSION_SECRET'] = SecureRandom.hex(32)
	end
	
	exec('guard', '-g', 'development,test')
end

desc 'Start an interactive console for your web application'
task :console => :environment do
	require 'pry'
	require 'rack/test'
	
	include Rack::Test::Methods
	
	def app
		@app ||= Rack::Builder.parse_file(File.expand_path("../config.ru", __dir__)).first
	end
	
	Pry.start
end