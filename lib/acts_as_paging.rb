#==ActsAsPaging
#
#  在需要使用的模型添加如下代码：
#    include ActsAsPaging
#    acts_as_paging :paging_filter => :search
#    其中参数paging_filter 指向一个模型对象的搜索过滤功能的方法名(必须存在此方法才可以用)
#  
#  在application_controller.rb文件添加如下代码：
#    include ActsAsPaging::Support
#
#    在有使用到分页工具栏的action加上: build_paging_params(object/collection, search_conditions=nil)
#    其中object参数可能是分页集合对象或一个实例对象，具体使用如下：
#    search action: build_paging_params(@posts)
#    show/edit action: build_paging_params(@post, 'title', 'body')
#  
#  在application_helper.rb文件添加如下代码：
#    include ActsAsPaging::Helper
#
#  Views可以使用的参数
#    @paging_params 查找记录的条件参数
#    @paging  分页的参数，默认url是: post_path，如果是特殊的url要加上参数path，如 :path => 'edit_post_path'
#    @paging_params和@paging直接使用即可
#    
#  Views具体使用如下:
#    search page: link to show/edit page 
#      <%= link_to post.id, post_path(@post, @paging_params) %> or
#      <%= link_to post.id, edit_post_path(@post, @paging_params) %>
#    show/edit page
#      <%= paging_bar(@post, @paging, @paging_params) %> or
#      <%= paging_bar(@post, @paging.merge(:path => 'edit_post_path'), @paging_params) %>
#
#  CSS style:
#    .page a {
#      background: #ccc;
#      text-decoration: none;
#      padding: 5px 10px;
#    }
#    .page a:hover {
#      background: #eee;
#    }
#

#require 'ruby-debug'

module ActsAsPaging

  def self.included(base)
    base.extend(ClassMethods)
    base.send(:include, InstanceMethods)
  end

  module ClassMethods
  
    def acts_as_paging( options = {} )
      raise "Not found options 'paging_filter'" unless options[:paging_filter]

      write_inheritable_attribute :paging_filter, options[:paging_filter]
      class_inheritable_reader :paging_filter
    end
      
    def paging_first(options = {})
      self.send(paging_filter, options).first(:select => "#{self.table_name}.id")
    end
    
    def paging_last(options = {})
      self.send(paging_filter, options).last(:select => "#{self.table_name}.id")
    end
    
    def paging_count(options = {})
      self.send(paging_filter, options).uniq.count
    end
  end
  
  module InstanceMethods
  
    def paging_prev(options = {})
      cl = self.class
      cl.send(paging_filter, options).first(:conditions => ["#{cl.table_name}.id < ?", self.id], :select => "#{cl.table_name}.id", :order => "#{cl.table_name}.created_at DESC")
    end
    
    def paging_next(options = {})
      cl = self.class
      cl.send(paging_filter, options).first(:conditions => ["#{cl.table_name}.id > ?", self.id], :select => "#{cl.table_name}.id")
    end
    
    def paging_index(options = {})
      cl = self.class
      all_ids = cl.send(paging_filter, options).all(:select => "#{cl.table_name}.id").map(&:id)
      all_ids.index(self.id) + 1
    end
  end
  
  module Support
    # entry是一个实例对象或集合
    def build_paging_params(entry, *paging_params)
      @paging, @paging_params = {}, {}

      return if entry.nil?

      if defined? WillPaginate::Collection and entry.kind_of?(WillPaginate::Collection)
        @paging[:t_count] =  entry.total_entries
      elsif entry.kind_of?(Array)
        @paging[:t_count] =  entry.size
      else
        @paging = set_paging(entry)
      end
      
      paging_params.each do |_p|
        next if params[_p].blank?
        @paging_params[_p] = params[_p]
      end
    rescue
      @paging, @paging_params = {}, {}
    end  
    
    def set_paging(entry)
      paging = {}

      return {} if entry.class.paging_count(params) == 0
      
      if entry.new_record?
        first_record = entry.class.paging_first
        paging[:prev_id] = nil
        paging[:next_id] = first_record.nil? ? nil : first_record.id
        paging[:c_index] = 0      
      else
        paging[:next_id] = params[:n].blank?   ? (entry.paging_next(params).nil? ? nil : entry.paging_next(params).id)  : params[:n]
        paging[:prev_id] = params[:p].blank?   ? (entry.paging_prev(params).nil? ? nil : entry.paging_prev(params).id)  : params[:p]
        paging[:c_index] = params[:c_i].blank? ? entry.paging_index(params) : params[:c_i]
      end
      
      paging[:head_id] = params[:h].blank?   ? entry.class.paging_first(params).id : params[:h]
      paging[:tail_id] = params[:t].blank?   ? entry.class.paging_last(params).id  : params[:t]
      paging[:t_count] = params[:t_c].blank? ? entry.class.paging_count(params) : params[:t_c]
      paging
    rescue
      {}
    end
        
  end
  
  module Helper
    def paging_bar(current_entry, paging = {}, paging_params = {})
      return nil if current_entry.nil? or current_entry.class.paging_count(params) == 0
      
      if current_entry.class.paging_count(params) == 1
        prev_index = next_index = 1
      else
        prev_index = paging[:c_index].to_i - 1
        next_index = paging[:c_index].to_i + 1
      end
      next_index = paging[:t_count] if next_index > paging[:t_count].to_i
      prev_index = 1 if next_index == 0
      share_params = { :t_c => paging[:t_count], :h => paging[:head_id], :t => paging[:tail_id]}.merge(paging_params)
      
      paging_tags = "
        <div class='page fr'>
          <a href='#{ paging[:c_index] == "1" ? "#" : parse_link(current_entry, paging[:head_id], {:c_i => 1}.merge(share_params), paging[:path] )}' class='btt'>│&lt;</a>
          <a href='#{paging[:prev_id].blank? ? "#" : parse_link(current_entry, paging[:prev_id], {:n => current_entry.id, :c_i => prev_index}.merge(share_params), paging[:path]) }' class='btt bttb'>&lt;</a>
          <a href='#' class='btt'> #{paging[:c_index]} /  #{paging[:t_count]}</a>
          <a href='#{ paging[:next_id].blank? ? "#" : parse_link(current_entry, paging[:next_id], {:p => current_entry.id, :c_i => next_index}.merge(share_params), paging[:path]) }' class='btt bttb'>&gt;</a>
          <a href='#{ paging[:c_index] == paging[:t_count] ? "#" : parse_link(current_entry, paging[:tail_id], {:c_i => paging[:t_count]}.merge(share_params), paging[:path] )}' class='btt'>&gt;│</a>
        </div>"

      paging_tags
    rescue
    end
    
    def parse_link(entry, _id, opts = {}, specified_path = nil)
      return '#' if entry.blank? or _id.blank?
      
      the_entry_path = specified_path.blank? ? "#{entry.class.to_s.underscore}_path" : specified_path

      tmp_a = []
      opts.each { |k,v| tmp_a << ":#{k} => '#{v}'" }
      eval("#{the_entry_path} #{_id}, {#{tmp_a.join(',')}}")
    rescue
      '#'
    end       
  end
end
