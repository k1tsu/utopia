# Copyright, 2014, by Samuel G. D. Williams. <http://www.codeotaku.com>
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

require 'utopia/path'
require 'utopia/http'

module Utopia
	module Middleware
		class Controller
			class Base
				def self.base_path
					self.const_get(:BASE_PATH)
				end
			
				def self.uri_path
					self.const_get(:URI_PATH)
				end
			
				def self.controller
					self.const_get(:CONTROLLER)
				end
				
				class << self
					def require_local(path)
						require File.join(base_path, path)
					end
					
					def direct?(path)
						path.dirname == uri_path
					end
					
					def actions
						@actions ||= Action.new
					end
					
					def on(path, options = {}, &block)
						actions.define(Path[path].components, options, &block)
					end
					
					def lookup(path)
						possible_actions = actions.select((path - uri_path).components)
					end
					
					def method_added(name)
						if name.match(/^on_(.*)$/)
							warn "Method #{name} using legacy definition mechanism."
							on($1.split("_").join('/'), unbound: true, &name)
						end
					end
				end
				
				def lookup(path)
					self.class.lookup(path)
				end
				
				# Given a request, call an associated action if one exists.
				def passthrough(request, path)
					actions = lookup(path)
					
					if actions.size > 0
						variables = request.controller
						controller_clone = self.clone
						
						variables << controller_clone
						
						response = catch(:response) do
							# By default give nothing - i.e. keep on processing:
							actions.each do |action|
								action.invoke!(controller_clone, request, path)
							end and nil
						end
						
						if response
							return controller_clone.respond_with(*response)
						end
					end
					
					return nil
				end

				def call(env)
					self.class.controller.app.call(env)
				end

				def respond!(*args)
					throw :response, args
				end

				def ignore!
					throw :response, nil
				end

				def redirect! (target, status = 302)
					respond! :redirect => target.to_str, :status => status
				end

				def rewrite! location
					throw :rewrite, location.to_str
				end

				def fail!(error = :bad_request)
					respond! error
				end

				def success!(*args)
					respond! :success, *args
				end
				
				def respond_with(*args)
					return args[0] if args[0] == nil || Array === args[0]

					status = 200
					options = nil

					if Numeric === args[0] || Symbol === args[0]
						status = args[0]
						options = args[1] || {}
					else
						options = args[0]
						status = options[:status] || status
					end

					status = Utopia::HTTP::STATUS_CODES[status] || status
					headers = options[:headers] || {}

					if options[:type]
						headers['Content-Type'] ||= options[:type]
					end

					if options[:redirect]
						headers["Location"] = options[:redirect]
						status = 302 if status < 300 || status >= 400
					end

					body = []
					if options[:body]
						body = options[:body]
					elsif options[:content]
						body = [options[:content]]
					elsif status >= 300
						body = [Utopia::HTTP::STATUS_DESCRIPTIONS[status] || "Status #{status}"]
					end

					# Utopia::LOG.debug([status, headers, body].inspect)
					return [status, headers, body]
				end
				
				# Return nil if this controller didn't do anything. Request will keep on processing. Return a valid rack response if the controller can do so.
				def process!(request, path)
					passthrough(request, path)
				end
			end
		end
	end
end