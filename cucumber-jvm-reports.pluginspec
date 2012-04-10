Jenkins::Plugin::Specification.new do |plugin|
  plugin.name = "cucumber-jvm-reports"
  plugin.display_name = "Cucumber JVM Reports Plugin"
  plugin.version = '0.0.1'
  plugin.description = 'Publish Cucumber JVM Html reports'

  plugin.url = 'https://wiki.jenkins-ci.org/display/JENKINS/git-notes+Plugin'

  plugin.developed_by "kingsleyh", "Kingsley Hendrickse <kingsley.hendrickse@gmail.com>"

  plugin.uses_repository :github => 'masterthought/jenkins-cucumber-jvm-reports-plugin'

  plugin.depends_on 'ruby-runtime', '0.10'
end
