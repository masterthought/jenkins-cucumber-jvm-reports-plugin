require 'fileutils'
require 'java'
require 'jenkins/rack'
require 'sinatra/base'
require File.dirname(__FILE__) + "/single_result_parser.rb"

module CucumberReport

  class CucumberPublishedReportAction
    include Java.hudson.model.Action

    def initialize(attrs = {})
      @project = attrs[:native].get_project.name
      @build_number = attrs[:native].get_number
    end

    def getDisplayName
      "Cucumber Reports"
    end

    def getIconFileName
      "graph.gif"
    end

    def getUrlName
      "/cucumber-html-reports/overview?build_project=#{@project}&build_number=#{@build_number}"
    end

  end
end

class CucumberReportWidget < Java.hudson.widgets.Widget
  include Java.hudson.model.RootAction

  def getIconFileName
    nil
  end

  def getDisplayName
    'Cucumber Html Reports'
  end

  def getUrlName
    'cucumber-html-reports'
  end

  def initialize
    super
    @action = CucumberReportAction.new(self)
    @jenkins = Java.jenkins.model.Jenkins.instance
  end

  include Jenkins::RackSupport

  def call(env)
    @action.call(env)
  end

  def view_names
    names = []
    @jenkins.views.each { |view|
      names << view.view_name
    }
    names
  end

  def view_name
    unless @config[VIEW]
      @config[VIEW] = @jenkins.primary_view.view_name
      @config.save
    end
    @config[VIEW]
  end

end

class CucumberReportAction < Sinatra::Base

  def initialize(widget)
    super
    @widget = widget
  end

  # The first line works for development but not in the latest version of jenkins - so switch these around to the shorter one when running in dev as jpi server
  # set :public_folder, "#{Dir.pwd}/views/reports"
  set :public_folder, "#{Java.jenkins.model.Jenkins.getInstance.root_dir.absolute_path + '/plugins/cucumber-jvm-reports/WEB-INF/classes/reports'}"

  get '/overview' do
    # project = params[:project]
    build_project = params[:build_project]
    build_number = params[:build_number]
    report = "#{Java.jenkins.model.Jenkins.getInstance.root_dir.absolute_path}/jobs/#{build_project}/builds/#{build_number}/cucumber-html-reports/feature-overview.html"
    send_file(report)
  end

  get '/feature' do
    build_project = params[:build_project]
    build_number = params[:build_number]
    feature = params[:feature]
    report = "#{Java.jenkins.model.Jenkins.getInstance.root_dir.absolute_path}/jobs/#{build_project}/builds/#{build_number}/cucumber-html-reports/#{feature}"
    send_file(report)
  end

end


class CucumberReportPublisher < Jenkins::Tasks::Publisher

  include CucumberReport

  display_name "Publish cucumber results as a report"

  def initialize(attrs = {})
    @json_reports_dir = attrs["json_reports"]
  end

  def prebuild(build, listener)
  end

  def perform(build, launcher, listener)
    listener.info "Compiling Cucumber Html Reports"

    native = build.send(:native)

    json_reports_dir = native.workspace.to_s + "/" + @json_reports_dir
    build_dir = native.get_root_dir.to_s
    report_dir = build_dir + "/cucumber-html-reports"
    build_number = native.get_number
    build_project = native.get_project.name

    FileUtils.mkdir(report_dir) unless File.exists?(report_dir)
    json_results = Dir.glob(json_reports_dir + "/*.json")

    if !json_results.empty?
      listener.info("[CukeReport] copying json to reports directory: #{report_dir}")
      FileUtils.cp_r(json_results, report_dir)

      Dir.glob(report_dir + "/*.json").each do |json|
        SingleResultParser.new(json, report_dir, build_number, build_project).generate
      end
    else
      listener.error("[CukeReport] There were no json results found in: #{json_reports_dir}")
    end
    build.native.add_action(CucumberPublishedReportAction.new(:native => native))
  end


end

module CucumberReportViewManager
  def self.set_view(instance)
    root = FileUtils.pwd + '/views/'
    path = root + instance.getClass.getName.gsub(/[.$]/, '/')
    FileUtils.mkdir_p path
    FileUtils.cp_r Dir.glob(root + '/' + instance.class.name + '/*'), path
  end
end

widget = CucumberReportWidget.new
CucumberReportViewManager.set_view widget
Jenkins::Plugin.instance.peer.addExtension widget



