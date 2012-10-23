require 'watirmark/page/process_page'

# These methods are used in a Page Object to define how
# to interact with the application under test

module Watirmark
  module PageDefinition
    attr_accessor :keywords, :process_pages, :kwds, :perms, :keyword_metadata, :keyword_aliases
    attr_accessor :process_page_navigate_method, :process_page_submit_method,
                  :process_page_submit_method, :process_page_active_page_method


    @@browser = nil

    def inherited(klass)
      add_superclass_keywords(klass)
      add_superclass_permissions(klass)
      add_superclass_process_pages(klass)
      create_default_process_page(klass)
    end

    def keyword(name, map=nil, &block)
      create_new_keyword(name, map, permissions={:populate => true, :verify => true}, &block)
    end

    def populate_keyword(name, map=nil, &block)
      create_new_keyword(name, map, permissions={:populate => true}, &block)
    end

    def verify_keyword(name, map=nil, &block)
      create_new_keyword(name, map, permissions={:verify => true}, &block)
    end

    def private_keyword(name, map=nil, &block)
      create_new_keyword(name, map, &block)
    end
    alias :navigation_keyword :private_keyword


    # Create an alias to an existing keyword
    def keyword_alias(keyword_alias_name, keyword_name)
      @keyword_aliases ||= Hash.new { |h, k| h[k] = Array.new }
      @keyword_aliases[keyword_name] << keyword_alias_name
    end

    def process_page(name, method=nil)
      @current_process_page = find_or_create_process_page(name)
      yield
      @current_process_page = @current_process_page.parent
    end

    def process_page_alias(x)
      @current_process_page.alias << x
    end

    def always_activate_parent
      @current_process_page.always_activate_parent = @current_process_page.parent.page_name
    end

    def browser
      @@browser ||= Watirmark::Session.instance.openbrowser
    end

    def browser=(x)
      @@browser = x
    end

    def keywords
      @kwds.values.flatten.uniq.sort_by { |key| key.to_s }
    end

    def native_keywords
      @kwds[self].sort_by { |key| key.to_s }
    end


    def permissions
      @perms ||= Hash.new { |h, k| h[k] = Hash.new }
      @perms.values.inject(:merge)
    end


    private


    def create_new_keyword(name, map=nil, permissions, &block)
      add_to_keywords(name)
      add_permission(name, permissions)
      @current_process_page << name if permissions
      @keyword_metadata ||= Hash.new { |h, k| h[k]=Hash.new }
      @keyword_metadata[name][:key] = name
      @keyword_metadata[name][:map] = map
      @keyword_metadata[name][:permissions] = permissions
      @keyword_metadata[name][:block] = block
      @keyword_metadata[name][:process_page] = @current_process_page
    end

    def add_permission(kwd, hash)
      @perms ||= Hash.new { |h, k| h[k] = Hash.new }
      @perms[self][kwd] = hash
    end

    def add_to_keywords(method_sym)
      @kwds ||= Hash.new { |h, k| h[k] = Array.new }
      @kwds[self] << method_sym unless @kwds.include?(method_sym)
    end

    def add_superclass_keywords(klass)
      if @kwds
        klass.kwds ||= Hash.new { |h, k| h[k] = Array.new }
        @kwds.each_key do |k|
          klass.kwds[k] = @kwds[k].dup
        end
      end
    end

    def add_superclass_process_pages(klass)
      klass.process_pages = (@process_pages ? @process_pages.dup : klass.process_pages = [])
    end

    def add_superclass_permissions(klass)
      if @perms
        klass.perms ||= Hash.new { |h, k| h[k] = Hash.new }
        @perms.each_key do |k|
          klass.perms[k] = @perms[k].dup
        end
      end
    end

    def create_default_process_page(klass)
      klass.instance_variable_set :@current_process_page, ProcessPage.new(klass.inspect)
      current_page = klass.instance_variable_get(:@current_process_page)
      current_page.root = true
      klass.process_pages << current_page
    end

    def find_or_create_process_page(name)
      mypage = find_process_page(name)
      unless mypage
        mypage = ProcessPage.new(name, @current_process_page)
        @process_pages ||= []
        @process_pages << mypage
      end
      mypage.navigate_method = @process_page_navigate_method
      mypage.submit_method = @process_page_submit_method
      mypage.active_page_method = @process_page_active_page_method
      mypage
    end

    def find_process_page(name)
      name = @current_process_page.name + ' > ' + name unless @current_process_page.root
      @process_pages.find { |p| p.name == name }
    end
  end

end