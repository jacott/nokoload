require 'nokoload/runner'

require 'csv'
require 'forwardable'

module Nokoload
  extend Forwardable
  STAT_FORMAT="%-30s , %6.4f , %5d , %6.4f , %6.4f\n"
  STAT_CSV_FORMAT="%s,%.4f,%d,%.4f,%.4f\n"
  STAT_CSV_HEADER_FORMAT=STAT_CSV_FORMAT.gsub(/(\.4)?[df]/,'s')

  def_delegators :_runner, :run, :wait_for_run, :step, :submit, :css, :content, :wall_time,
  :step_times, :request_times, :response_body, :xhr, :read_timeout

  def show_stats(csv=nil)
    if csv
      format=STAT_CSV_FORMAT
      sprintf(STAT_CSV_HEADER_FORMAT, 'step', 'mean', 'count', 'max', 'min')
    else
      format=STAT_FORMAT
      ''
    end <<
    stats.map do |stat|
      sprintf(format, CSV.generate_line([stat[0]]).strip, *stat[1..-1])
    end.join
  end

  def host(host)
    _runner.url=URI::parse(host.sub(%r{/$},''))
  end

  def stop_on_first_exception
    _runner.stop_on_first_exception=true
  end

  def show_output
    puts _runner.rep_doc
  end

  def get(url,payload=nil,headers=nil)
    _runner.comm(:get,url,payload,headers)
  end

  def post(url,payload=nil,headers=nil)
    _runner.comm(:post,url,payload,headers)
  end

  def follow_link(title,css="a")
    if elm=_runner.content(title,css)
      get elm['href']
    else
      raise "link '#{title}' not found"
    end
  end

  def post_link(title,params,css="a")
    if elm=_runner.content(title,css)
      post elm['href'], params
    else
      raise "link '#{title}' not found"
    end
  end

  def trace(on=true)
    _runner.trace=on
  end

  def warp_time(warp_factor=nil)
    @_warp_factor=warp_factor*1.0 if warp_factor
  end

  def warp_factor
    @_warp_factor
  end

  def after(seconds)
    _runner.after seconds/(@_warp_factor||1.0)
  end

  def while_running(time=0.1)
    while _runner.running?
      sleep time
      yield
    end
  end

  def wait_for_run
    _runner.wait_for_run
  end

  def stats
    _runner.sync{
      result=[]
      step_times.each_pair do |k,v|
        total=v.inject{|s,t| s+t}
        result << [k, total/v.size, v.size, v.max, v.min]
      end
      result
    }
  end

  def _runner
    @_runner||=Nokoload::Runner.new
  end
  private :_runner
end

