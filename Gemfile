source 'https://rubygems.org'

# basics
ruby '1.9.3'
gem 'rails', '4.0.5'
gem 'thin'

# asset pipeline; look & feel
gem 'sprockets'
gem 'sass-rails'
gem 'uglifier'
gem 'jquery-rails'
gem 'jquery-ui-rails'
gem 'turbolinks'
# gem 'jbuilder', '1.0.2'
gem 'ejs'
gem 'will_paginate'

# authentication
gem 'devise'
gem 'omniauth'
gem 'omniauth-facebook'
gem 'omniauth-linkedin'
gem 'omniauth-github'
gem 'omniauth-google-oauth2'

# authorization
gem 'pundit'

# data structure
gem 'ancestry'
gem 'acts_as_list'

# other
gem 'faker', '1.1.2'
gem 'ckeditor_rails'
gem 'annotate', '~> 2.6.5'
gem 'amatch'

group :development do
  gem 'meta_request'
	gem 'bullet'
end


group :development, :test do
  gem 'sqlite3', '1.3.8'
  gem 'rspec-rails', '2.13.1'
  gem 'guard-rspec', '2.5.0'
  gem 'spork-rails'
  gem 'guard-spork'
  gem 'childprocess'
  gem 'rb-notifu', '0.0.4'
  gem 'wdm', '0.1.0'
end

group :test do
  gem 'selenium-webdriver', '2.35.1'
  gem 'capybara', '2.1.0'
  gem 'factory_girl_rails', '4.2.0'
	gem 'cucumber-rails', '1.4.0', :require => false
  gem 'database_cleaner', github: 'bmabey/database_cleaner'
end

group :doc do
  gem 'sdoc', '0.3.20', require: false
end

group :production do
  gem 'pg', '0.15.1'
  gem 'rails_12factor', '0.0.2'
end

# nlp
gem 'treat'
gem 'activesupport'
gem 'stanford-core-nlp', '0.5.1'
gem 'scalpel'

# Other treat gems that may need to be re-included for future nlp tasks
#gem 'linguistics'
#gem 'engtagger'
#gem 'open-nlp'
#gem 'rwordnet'
#gem 'fastimage'
#gem 'decisiontree'
#gem 'whatlanguage'
#gem 'zip'
#gem 'nickel'
#gem 'tactful_tokenizer'
#gem 'srx-english'
#gem 'punkt-segmenter'
#gem 'chronic'
#gem 'uea-stemmer'
#gem 'ruby-stemmer'
#gem 'rb-libsvm'
#gem 'ruby-fann'
#gem 'fuzzy-string-match'
#gem 'tf-idf-similarity'
#gem 'kronic'
#gem 'graphr'