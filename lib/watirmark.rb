if RUBY_VERSION != "1.9.3"
  warn "
************************************************************************
Using unsupported Ruby version #{RUBY_VERSION}. Please upgrade to 1.9.3
************************************************************************
"
end

require 'watirmark/configuration'
Watirmark::Configuration.instance.reload

require 'watirmark/at_exit'
require 'watir-webdriver'
require 'watirmark/extensions/webdriver_extensions'
require 'watirmark/extensions/ruby_extensions'
require 'watirmark/session'
require 'watirmark/exceptions'
require 'watirmark/page/keyed_element'
require 'watirmark/page/page'
require 'watirmark/controller/controller'
require 'american_date'
require 'uuid'
require 'watirmark/model'
require 'watirmark/rake/smoketest'
require 'active_support/inflector'
FileUtils.rm_rf('reports/screenshots')
