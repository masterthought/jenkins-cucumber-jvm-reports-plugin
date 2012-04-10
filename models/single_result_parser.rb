require 'rubygems'
require 'json'
require 'pp'
require 'ostruct'

class SingleResultParser

  def initialize(json_result, report_dir, build_number, build_project)
    @data = JSON.parse(File.read(json_result))
    @report_dir = report_dir
    @build_number = build_number
    @build_project = build_project
    @features = features
    @statistics = statistics
  end

  def generate
    generate_report
    generate_overview
    generate_chart_data
  end

  def generate_report
    @features.each do |feature|
      File.open(@report_dir + "/" + feature.file + ".html", "w") { |f|
        f.puts feature_page_head(feature.name)
        f.puts feature_page_body_result
        f.puts "<div class=\"#{feature.status}\">" + feature.name + "</div>"
        f.puts feature.description

        feature.scenarios.each do |scenario|
          f.puts scenario.tags
          f.puts "<div class=\"#{scenario.status}\">" + scenario.name + "</div>"
          scenario.steps.each do |step|

            if step.status == "failed"
              f.puts "<div class=\"#{step.status}\">" + step.name + "<div class=\"step-error-message\"><pre>#{step.error_message}</pre></div></div>"
            else
              f.puts "<div class=\"#{step.status}\">" + step.name + "</div>"
            end

          end
        end
        f.puts feature_page_body_stats(feature)
      }
    end
  end

  def generate_overview
    File.open(@report_dir + "/" + "feature-overview.html", "w") { |f|
      f.puts feature_overview_page_head
      f.puts feature_overview_page_body
      f.puts feature_overview_page_foot
    }
  end

  def generate_chart_data
    File.open(@report_dir + "/" + "feature-overview.xml", "w") { |f|
      f.puts chart_data
    }
  end

  def features
    features = []
    @data.each do |feature|

      scenarios = []
      feature["elements"].each do |scenario|

        steps = []
        scenario["steps"].each do |step|
          steps << OpenStruct.new(:name => step_name(step["keyword"], step["name"]), :status => status(step["result"]), :error_message => error_message(step["result"]))
        end
        scenarios << OpenStruct.new(:name => scenario_name(scenario["keyword"], scenario["name"]), :status => scenario_status(steps), :steps => steps, :tags => tags(scenario["tags"]))
      end

      features << OpenStruct.new(:name => feature_name(feature["name"]), :file => feature["uri"].gsub("/", "-"), :description => feature_description(feature["description"]), :scenarios => scenarios, :status => feature_status(scenarios))
    end
    features
  end

  private

  def feature_name(feature)
    item_exists?(feature) ? "<div class=\"feature-line\"><span class=\"feature-keyword\">Feature:</span> #{feature}</div>" : ""
  end

  def feature_description(description)
    result = ""
    if item_exists?(description)
      content = description.sub(/^As an/, "<span class=\"feature-role\">As an</span>")
      content = content.sub(/^I want to/, "<span class=\"feature-action\">I want to</span>")
      content = content.sub(/^So that/, "<span class=\"feature-value\">So that</span>")
      content = content.gsub("\n", "<br/>")
      result = "<div class=\"feature-description\">#{content}</div>"
    end
    result
  end

  def tags(tags)
    result = "<div class=\"feature-tags\"></div>"
    if item_exists?(tags)
      tags = tags.collect { |tag| tag["name"] }.join(",")
      result = "<div class=\"feature-tags\">#{tags}</div>"
    end
    result
  end

  def scenario_name(keyword, scenario_name)
    content_string = []
    content_string << "<span class=\"scenario-keyword\">#{keyword}: </span>" if item_exists?(keyword)
    content_string << "<span class=\"scenario-name\">#{scenario_name}</span>" if item_exists?(scenario_name)
    item_exists?(content_string) ? content_string.join("").to_s : ""
  end

  def step_name(keyword, step_name)
    result = ""
    if item_exists?(keyword) and item_exists?(step_name)
      result = "<span class=\"step-keyword\">#{keyword}</span><span class=\"step-name\">#{step_name}</span>"
    end
    result
  end

  def scenario_status(steps)
    steps.collect { |s| s.status }.include?("failed") ? "failed" : "passed"
  end

  def feature_status(scenarios)
    scenarios.collect { |s| s.status }.include?("failed") ? "failed" : "passed"
  end

  def status(item)
    item["status"].to_s
  end

  def error_message(item)
    item["error_message"].to_s
  end

  def item_exists?(item)
    !(item.nil? or item.empty?)
  end

  def statistics
    total_features = @features.size
    total_scenarios = @features.collect { |f| f.scenarios.size }.inject { |sum, x| sum + x }
    total_steps = @features.collect { |f| f.scenarios.collect { |s| s.steps.size } }.flatten.inject { |sum, x| sum + x }
    total_passed = @features.collect { |f| f.scenarios.collect { |s| step_size(s.steps, "passed") } }.flatten.inject { |sum, x| sum + x }
    total_failed = @features.collect { |f| f.scenarios.collect { |s| step_size(s.steps, "failed") } }.flatten.inject { |sum, x| sum + x }
    total_skipped = @features.collect { |f| f.scenarios.collect { |s| step_size(s.steps, "skipped") } }.flatten.inject { |sum, x| sum + x }
    totals = OpenStruct.new(:features => total_features, :scenarios => total_scenarios, :steps => total_steps, :passed => total_passed, :failed => total_failed, :skipped => total_skipped)

    features = []
    @features.each do |feature|
      steps = feature.scenarios.collect { |sc| sc.steps.size }.inject { |sum, x| sum + x }
      passed = feature.scenarios.collect { |s| step_size(s.steps, "passed") }.inject { |sum, x| sum + x }
      failed = feature.scenarios.collect { |s| step_size(s.steps, "failed") }.inject { |sum, x| sum + x }
      skipped = feature.scenarios.collect { |s| step_size(s.steps, "skipped") }.inject { |sum, x| sum + x }
      features << OpenStruct.new(:name => feature.name, :scenarios => feature.scenarios.size, :steps => steps, :passed => passed, :failed => failed, :skipped => skipped, :status => feature.status, :file => feature.file)
    end

    OpenStruct.new(:totals => totals, :features => features)
  end

  def step_size(steps, status)
    steps.collect { |s| s if s.status == status }.compact.size
  end

  def stats_totals_table
    head=<<-EOF
  <br/>
  <h2>Feature Statistics</h2>
  <table class="stats-table">
  <tr>
  <th>Feature</th>
  <th>Scenarios</th>
  <th>Steps</th>
  <th>Passed</th>
  <th>Failed</th>
  <th>Skipped</th>
  <th>Status</th>
  </tr>  
    EOF
    content = []
    @statistics.features.each do |feature|
      content << "<tr>"
      content << "<td><a href=\"feature?build_project=#{@build_project}&build_number=#{@build_number}&feature=#{feature.file+'.html'}\">#{feature.name}</a></td>"
      content << "<td>#{feature.scenarios}</td>"
      content << "<td>#{feature.steps}</td>"
      content << "<td>#{feature.passed}</td>"
      content << "<td>#{feature.failed}</td>"
      content << "<td>#{feature.skipped}</td>"
      status = feature.status == "passed" ? "#C5D88A" : "#D88A8A"
      content << "<td style=\"background-color:#{status};\">#{feature.status}</td>"
      content << "<tr>"
    end

    totals = []
    totals << "<tr>"
    totals << "<td style=\"background-color:lightgray;font-weight:bold;\">#{@statistics.totals.features}</td>"
    totals << "<td style=\"background-color:lightgray;font-weight:bold;\">#{@statistics.totals.scenarios}</td>"
    totals << "<td style=\"background-color:lightgray;font-weight:bold;\">#{@statistics.totals.steps}</td>"
    totals << "<td style=\"background-color:lightgray;font-weight:bold;\">#{@statistics.totals.passed}</td>"
    totals << "<td style=\"background-color:lightgray;font-weight:bold;\">#{@statistics.totals.failed}</td>"
    totals << "<td style=\"background-color:lightgray;font-weight:bold;\">#{@statistics.totals.skipped}</td>"
    totals << "<td style=\"background-color:lightgray;font-weight:bold;\">Totals</td>"
    totals << "</tr>"

    foot="</table>"
    head+content.join("\n").to_s+totals.join("\n").to_s+foot
  end

  def stats_table_header
    table=<<-EOF
<br/>
<h2>Feature Statistics</h2>
<table class="stats-table">
<tr>
<th>Feature</th>
<th>Scenarios</th>
<th>Steps</th>
<th>Passed</th>
<th>Failed</th>
<th>Skipped</th>
<th>Status</th>
</tr>  
    EOF
  end

  def stats_table_content(feature)
    content = []
    content << "<tr>"
    content << "<td><a href=\"feature?build_project=#{@build_project}&build_number=#{@build_number}&feature=#{feature.file+'.html'}\">#{feature.name}</a></td>"
    content << "<td>#{feature.scenarios.size}</td>"

    steps = []
    passed = []
    failed = []
    skipped = []
    feature.scenarios.each do |scenario|
      scenario.steps.each do |step|
        steps << step
        passed << step if step.status == "passed"
        failed << step if step.status == "failed"
        skipped << step if step.status == "skipped"
      end

    end

    content << "<td>#{steps.size}</td>"
    content << "<td>#{passed.size}</td>"
    content << "<td>#{failed.size}</td>"
    content << "<td>#{skipped.size}</td>"
    status = feature.status == "passed" ? "#C5D88A" : "#D88A8A"
    content << "<td style=\"background-color:#{status};\">#{feature.status}</td></tr>"
    content.join("\n")
  end

  def stats_table_footer
    "</table>"
  end

  def css
    css=<<-EOF
<style>
.feature-keyword{font-weight:bold;}
.feature-description{padding-left:15px;font-style:italic;background-color:beige;}
.feature-role{font-weight:bold;}
.feature-action{font-weight:bold;}
.feature-value{font-weight:bold;}
.feature-tags{padding-top:10px;padding-left:15px;color:darkblue;}
.scenario-keyword{font-weight:bold;padding-left:15px;}
.scenario-scenario_name{padding-left:15px;}
.step-keyword{font-weight:bold;padding-left:50px;}
.step-error-message{background-color:#FFEEEE;padding-left:50px;border: 1px solid #D88A8A;}
.passed{background-color:#C5D88A;}
.failed{background-color:#D88A8A;}
.skipped{background-color:#2DEAEC;}

table.stats-table {
	color:black;
	border-width: 1px;
	border-spacing: 2px;
	border-style: outset;
	border-color: gray;
	border-collapse: collapse;
	background-color: white;
}
table.stats-table th {
	color:black;
	border-width: 1px;
	padding: 5px;
	border-style: inset;
	border-color: gray;
	background-color: #66CCEE;
	-moz-border-radius: ;
}
table.stats-table td {
  color:black;
  text-align: center;
	border-width: 1px;
	padding: 5px;
	border-style: inset;
	border-color: gray;
	background-color: white;
	-moz-border-radius: ;
}
</style>
    EOF
  end

  def show_chart
    html=<<-EOF
<script language="JavaScript" type="text/javascript">
<!--
if (AC_FL_RunContent == 0 || DetectFlashVer == 0) {
	alert("This page requires AC_RunActiveContent.js.");
} else {
	var hasRightVersion = DetectFlashVer(requiredMajorVersion, requiredMinorVersion, requiredRevision);
	if(hasRightVersion) { 
		AC_FL_RunContent(
			'codebase', 'http://download.macromedia.com/pub/shockwave/cabs/flash/swflash.cab#version=10,0,45,2',
			'width', '480',
			'height', '300',
			'scale', 'noscale',
			'salign', 'TL',
			'bgcolor', '#bbccff',
			'wmode', 'opaque',
			'movie', 'charts/charts',
			'src', 'charts/charts',
			'FlashVars', "library_path=charts/charts_library&xml_data=#{chart_data.gsub("\n", "").gsub(/>\s+</, "><")}",
			'id', 'my_chart',
			'name', 'my_chart',
			'menu', 'true',
			'allowFullScreen', 'true',
			'allowScriptAccess','sameDomain',
			'quality', 'high',
			'align', 'middle',
			'pluginspage', 'http://www.macromedia.com/go/getflashplayer',
			'play', 'true',
			'devicefont', 'false'
			); 
	} else { 
		var alternateContent = 'This content requires the Adobe Flash Player. '
		+ '<u><a href=http://www.macromedia.com/go/getflash/>Get Flash</a></u>.';
		document.write(alternateContent); 
	}
}
// -->
</script>
<noscript>
	<P>This content requires JavaScript.</P>
</noscript>
    EOF
  end

  def chart_data
    html=<<-EOF
<chart>
  <license>JTAMVPF7P2O.H4X5CWK-2XOI1X0-7L</license> 
	<chart_data>
		<row>
			<null/>
			<string>Passed</string>
			<string>Failed</string>
			<string>Skipped</string>
		</row>
		<row>
			<string></string>
			<number shadow='high' bevel='data' line_color='FFFFFF' line_thickness='3' line_alpha='75'>#{@statistics.totals.passed}</number>
			<number shadow='high' bevel='data' line_color='FFFFFF' line_thickness='3' line_alpha='75'>#{@statistics.totals.failed}</number>
			<number shadow='high' bevel='data' line_color='FFFFFF' line_thickness='3' line_alpha='75'>#{@statistics.totals.skipped}</number>
		</row>
	</chart_data>
	<chart_label shadow='low' color='ffffff' alpha='95' size='10' position='inside' as_percentage='true' />
	<chart_pref select='true' />
	<chart_rect x='90' y='85' width='300' height='175' />
	<chart_transition type='scale' delay='1' duration='.5' order='category' />
	<chart_type>donut</chart_type>

	<draw>
		<rect transition='dissolve' layer='background' x='60' y='100' width='360' height='150' fill_alpha='0' line_color='ffffff' line_alpha='25' line_thickness='40' corner_tl='40' corner_tr='40' corner_br='40' corner_bl='40' />
		<circle transition='dissolve' layer='background' x='240' y='150' radius='150' fill_color='ccddff' fill_alpha='100' line_thickness='0' bevel='bg' blur='blur1' />
		<rect transition='dissolve' layer='background' shadow='soft' x='80' y='10' width='320' height='35' fill_color='ddeeff' fill_alpha='90' corner_tl='10' corner_tr='10' corner_br='10' corner_bl='10' />
	</draw>
	<filter>
		<shadow id='low' distance='2' angle='45' color='0' alpha='40' blurX='5' blurY='5' />
		<shadow id='high' distance='5' angle='45' color='0' alpha='40' blurX='10' blurY='10' />
		<shadow id='soft' distance='2' angle='45' color='0' alpha='20' blurX='5' blurY='5' />
		<bevel id='data' angle='45' blurX='5' blurY='5' distance='3' highlightAlpha='15' shadowAlpha='25' type='inner' />
		<bevel id='bg' angle='45' blurX='50' blurY='50' distance='10' highlightAlpha='35' shadowColor='0000ff' shadowAlpha='25' type='full' />
		<blur id='blur1' blurX='75' blurY='75' quality='1' />   
	</filter>
	
	<context_menu full_screen='false' />
	<legend transition='dissolve' x='90' width='300' bevel='low' fill_alpha='0' line_alpha='0' bullet='circle' size='12' color='000000' alpha='100' />

	<series_color>
		
		<color>88dd11</color>
		<color>cc1134</color>
		<color>88aaff</color>
	</series_color>
	<series_explode>
		<number>25</number>
		<number>0</number>
		<number>0</number>
	</series_explode>
	<series transfer='true' />

</chart>
    EOF
  end

  def feature_page_head(feature_name)
    html=<<-EOF
  <!DOCTYPE html>
  <html xmlns="http://www.w3.org/1999/xhtml">
  <head>
  <script language="javascript">AC_FL_RunContent = 0;</script>
  <script language="javascript"> DetectFlashVer = 0; </script>
  <script src="charts/AC_RunActiveContent.js" language="javascript"></script>
  <script language="JavaScript" type="text/javascript">
  <!--
  var requiredMajorVersion = 10;
  var requiredMinorVersion = 0;
  var requiredRevision = 45;
  -->
  </script>
  <meta http-equiv="Content-Type" content="text/html; charset=UTF-8" />
  	<title>Cucumber-JVM Html Reports - Feature: #{feature_name}</title>
  	<link rel="stylesheet" href="blue/css/style.css" type="text/css" media="screen" />
  	<link rel="stylesheet" href="blue/css/skin/style.css" type="text/css" media="screen" />
  	<link rel="stylesheet" href="blue/css/960.css" type="text/css" media="screen" />
  	<link rel="stylesheet" href="blue/css/reset.css" type="text/css" media="screen" />
  	<link rel="stylesheet" href="blue/css/text.css" type="text/css" media="screen" />
  	<link rel="shortcut icon" href="blue/favicon.ico" />
  #{css}
  </head>
    EOF
  end

  def feature_page_body_result
    html=<<-EOF
  <body id="top">
  	<div id="fullwidth_header">
  		<div class="container_12">
  			<h1 class="grid_4 logo"><a href="/cucumber-html-reports/overview?build_project=#{@build_project}&build_number=#{@build_number}" class='ie6fix'>Cucumber</a></h1>
  			<div class="grid_6" id="nav">
  				<ul>
  					<li><a href="/job/#{@build_project}/#{@build_number}">Back To Jenkins</a></li>
  					<li><a href="overview?build_project=#{@build_project}&build_number=#{@build_number}">Back To Overview</a></li>
  				</ul>
  			</div>   			
  		</div>		
  	</div>
  	<div id="fullwidth_gradient">
  		<div class="container_12">	
  			<div class="grid_9 heading">
  				<h2>Feature Result for Build: #{@build_number}</h2>
  				<span class="subhead">Below are the results for this feature:</span>
  			</div>
  		</div>	
  	</div>	

  	<div class="container_12">
  		<div class="grid_12">
  		<div style="color:black;">
    EOF
  end

  def feature_page_body_stats(feature)
    html=<<-EOF
  	</div>
  	<br/>
  		<div class="grid_12 hr"></div>

  	<div>
  	#{stats_table_header}
    #{stats_table_content(feature)}
    #{stats_table_footer}
  	</div>

  	</div>
  	</div>


  	<div class="container_12">
  		<div class="grid_12 hr"></div>
  		<div class="grid_12 footer">
  			<p style="text-align:center;">Cucumber-JVM Jenkins Report Plugin - #{Time.now}</p>
  		</div>
  	</div>
  	<div class="clear"></div>
  </body>
    EOF
  end

  def feature_overview_page_head
    html=<<-EOF
<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml">
<head>
<script language="javascript">AC_FL_RunContent = 0;</script>
<script language="javascript"> DetectFlashVer = 0; </script>
<script src="charts/AC_RunActiveContent.js" language="javascript"></script>
<script language="JavaScript" type="text/javascript">
<!--
var requiredMajorVersion = 10;
var requiredMinorVersion = 0;
var requiredRevision = 45;
-->
</script>
<meta http-equiv="Content-Type" content="text/html; charset=UTF-8" />
	<title>Cucumber-JVM Html Reports - Feature Overview</title>
	<link rel="stylesheet" href="blue/css/style.css" type="text/css" media="screen" />
	<link rel="stylesheet" href="blue/css/skin/style.css" type="text/css" media="screen" />
	<link rel="stylesheet" href="blue/css/960.css" type="text/css" media="screen" />
	<link rel="stylesheet" href="blue/css/reset.css" type="text/css" media="screen" />
	<link rel="stylesheet" href="blue/css/text.css" type="text/css" media="screen" />
	<link rel="shortcut icon" href="blue/favicon.ico" />
#{css}
</head>
    EOF
  end

  def feature_overview_page_body
    html=<<-EOF
<body id="top">
	<div id="fullwidth_header">
		<div class="container_12">
			<h1 class="grid_4 logo"><a href="/cucumber-html-reports/overview?build_project=#{@build_project}&build_number=#{@build_number}" class='ie6fix'>Cucumber</a></h1>
			<div class="grid_6" id="nav">
				<ul>
				<li><a href="/job/#{@build_project}/#{@build_number}">Back To Jenkins</a></li>
				</ul>
			</div>   			
		</div>		
	</div>
	<div id="fullwidth_gradient">
		<div class="container_12">	
			<div class="grid_9 heading">
				<h2>Feature Overview for Build: #{@build_number}</h2>
				<span class="subhead">The following graph shows number of steps passing, failing and skipped for this build:</span>
			</div>
		</div>	
	</div>	
 	
	<div class="container_12">
		<div class="grid_9">
	 <div style="text-align:center;">#{show_chart}</div>
	<br/>
		<div class="grid_12 hr"></div>
		
	<div>
	#{stats_totals_table}
	</div>
	
	</div>
	</div>
		
  
	<div class="container_12">
		<div class="grid_12 hr"></div>
		<div class="grid_12 footer">
			<p style="text-align:center;">Cucumber-JVM Jenkins Report Plugin - #{Time.now}</p>
		</div>
	</div>
	<div class="clear"></div>
</body>
    EOF
  end

  def feature_overview_page_foot
    "</html>"
  end

end


