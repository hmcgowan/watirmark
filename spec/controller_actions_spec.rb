require_relative 'spec_helper'

describe Watirmark::Actions do
  before :all do
    class ActionView < Page
      private_keyword(:a)
      private_keyword(:b)
    end

    class ActionController < Watirmark::WebPage::Controller
      @view = ActionView

      def create
      end

      def edit
      end

      def before_all
      end

      def before_each
      end

      def after_each
      end

      def after_all
      end
    end

    class ActionModel < Watirmark::Model::Factory
      keywords :a, :b
      defaults do
        a {1}
        b {2}
      end
    end
  end

  before :each do
    @controller = ActionController.new(ActionModel.new)
  end

  it 'before and after' do
    @controller.expects(:before_all).once
    @controller.expects(:after_all).once
    @controller.run :create
  end

  it 'before_each and after_each' do
    @controller.expects(:before_each).once
    @controller.expects(:after_each).once
    @controller.run :create
  end

  it 'before_each and after_each with multiple methods passed to run' do
    @controller.expects(:before_each).twice
    @controller.expects(:after_each).twice
    @controller.run :create, :edit
  end

  it 'use hashes instead of models' do
    controller = ActionController.new(a: 1, b: 2)
    controller.expects(:before_each).once
    controller.expects(:after_each).once
    controller.run :create
  end

  it 'records should be processed separately' do
    controller = ActionController.new
    controller.records << {a:1, b:2}
    controller.records << {c:3, d:4}
    controller.expects(:before_all).once
    controller.expects(:after_all).once
    controller.expects(:before_each).twice
    controller.expects(:after_each).twice
    controller.run :create
  end

  it 'records should be cleared after run' do
    controller = ActionController.new
    controller.records.should == []
    controller.records << {a:1, b:2}
    controller.records << {c:3, d:4}
    controller.records.should == [{a:1, b:2}, {c:3, d:4}]
    controller.run :create
    controller.records.should == []
  end

end
