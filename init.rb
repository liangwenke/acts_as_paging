#require 'acts_as_paging'
ActiveRecord::Base.send(:include, ActsAsPaging)
ActionController::Base.send(:include, ActsAsPaging::Support)
#ApplicationHelper.send(:include, ActsAsPaging::Helper)
