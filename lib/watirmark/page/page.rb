require 'watirmark/page/process_page'
require 'watirmark/page/radio_maps'

module Watirmark

  module KeywordMethods
    attr_accessor :keyword, :radio_map
  end

  class Page

    class << self
      @@browser = nil
      attr_accessor :keywords, :process_pages, :kwds, :perms

      def log
        Watirmark::Configuration.instance.logger
      end

      # When a view inherits another view, we want the subclass
      # to report the keywords and process pages pulling in all
      # subclasses. That way you can use the :keywords to see *all*
      # the available keywords and not just the ones explicitly defined
      # in that view.
      #
      # Also we want to create a default process page even if there is not
      # a process page in use. This allows us to handle each view the same way
      # and not have to see if it's using process pages or not.
      def inherited(klass)
        add_superclass_keywords(klass)
        add_superclass_permissions(klass)
        add_superclass_process_pages(klass)
        create_default_process_page(klass)
      end

      def keywords
        @kwds.values.flatten.uniq.sort_by { |key| key.to_s }
      end

      def native_keywords
        @kwds[self].sort_by { |key| key.to_s }
      end

      def keyword(name, map=nil, &block)
        create_new_keyword(name, map, permissions={:populate => true, :verify => true}, &block)
        @current_process_page << name
      end

      def populate_keyword(name, map=nil, &block)
        create_new_keyword(name, map, permissions={:populate => true}, &block)
        @current_process_page << name
      end

      def verify_keyword(name, map=nil, &block)
        create_new_keyword(name, map, permissions={:verify => true}, &block)
        @current_process_page << name
      end

      def private_keyword(name, map=nil, &block)
        create_new_keyword(name, map, &block)
      end
      alias :navigation_keyword :private_keyword

      def permissions
        @perms ||= Hash.new { |h, k| h[k] = Hash.new }
        @perms.values.inject(:merge)
      end

      # Create an alias to an existing keyword
      def keyword_alias(keyword_alias_name, keyword_name)
        keyword(keyword_alias_name) do
          warn("Warning: Deprecated use of `#{__callee__}` to access "\
              "`#{keyword_name}` with `#{keyword_alias_name}`in #{self}.")
          send keyword_name
        end
      end

      def process_page(name, method=nil)
        @current_process_page = find_or_create_process_page(name)
        @current_process_page.navigate_method = @process_page_navigate_method
        @current_process_page.submit_method = @process_page_submit_method
        @current_process_page.active_page_method = @process_page_active_page_method
        yield
        @current_process_page = @current_process_page.parent
      end

      def process_page_alias(x)
        @current_process_page.alias << x
      end

      def navigate_method(x)
        @process_page_navigate_method = x
      end

      def submit_method(x)
        @process_page_submit_method = x
      end

      def active_page_method(x)
        @process_page_active_page_method = x
      end

      def always_activate_parent
        @current_process_page.always_activate_parent = @current_process_page.parent.page_name
      end

      def [](x)
        @process_pages.each { |page| return page if page.name == x }
        raise RuntimeError, "Process Page '#{x}' not found in #{self}"
      end

      def browser
        @@browser ||= Watirmark::Session.instance.openbrowser
      end

      def browser=(x)
        @@browser = x
      end

    private

      def create_new_keyword(name, map=nil, permissions, &block)
        add_to_keywords(name)
        keyed_element = get_keyed_element(name, map, &block)
        add_permission(name, permissions)

        meta_def name do |*args|
          keyed_element.get *args
        end
        meta_def "#{name}=" do |*args|
          keyed_element.set *args
        end
      end

      def add_permission(kwd, hash)
        @perms ||= Hash.new { |h, k| h[k] = Hash.new }
        @perms[self][kwd] = hash
      end

      def add_to_keywords(method_sym)
        @kwds ||= Hash.new { |h, k| h[k] = Array.new }
        @kwds[self] << method_sym unless @kwds.include?(method_sym)
      end

      def get_keyed_element(method_sym, map=nil, &block)
        if map.is_a? Hash
          map = Watirmark::RadioMap.new map
        end
        Page::KeyedElement.new(
            :key => method_sym,
            :page => self,
            :map => map,
            :process_page => @current_process_page,
            :block => block
        )
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
        mypage
      end

      def find_process_page(name)
        name = @current_process_page.name + ' > ' + name unless @current_process_page.root
        @process_pages.find { |p| p.name == name }
      end

    end


    class KeyedElement
      def initialize(args)
        @key = args[:key]
        @page = args[:page]
        @map = args[:map]
        @process_page = args[:process_page]
        @block = args[:block]
        raise ArgumentError, "No process page defined! This should never happen" if @process_page.nil?
      end

      def get *args
        activate_process_page
        watir_object = @page.instance_exec(*args, &@block)
        watir_object.extend(KeywordMethods)
        watir_object.keyword = @key
        watir_object.radio_map = @map
        watir_object
      end

      def set val
        return if val.nil?
        activate_process_page
        element = get
        if @map
          val = @map.lookup(val)
        end
        case val
          when 'nil'
            element.clear # workaround to empty element values
          else
            case element
              when Watir::Radio
                element.set val
              when Watir::CheckBox
                val ? element.set : element.clear
              when Watir::Select
                element.select val
              when Watir::Button
                element.click
              else
                element.value = val
            end
        end
      end

      def activate_process_page
        @process_page.activate
      end
    end
  end
end

# Make this class a little easier to get to
Page = Watirmark::Page
