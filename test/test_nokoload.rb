require 'helper'
require 'nokoload'


class MyScript
  include Nokoload
  include Test::Unit::Assertions

  def run_script
    host "http://127.0.0.1:4567/"

    run 1 do |thread| # start 10 processes
      step 'get home page' do
        get '/'
        assert_equal 'Hello world!', response_body
      end
    end

    while_running(0.1) do
    end
    show_stats(:header)
  end
end



class TestNokoload < Test::Unit::TestCase
  def setup
    super
    @child=fork do
      begin
        Dir.chdir File.expand_path("#{__FILE__}/..")
        exec "shotgun -p 4567 #{File.expand_path('../sinatra_server.rb',__FILE__)} >../tmp/sinatra.log 2>&1"
      rescue => ex
        puts "Error! #{ex.message}\n#{ex.backtrace.join("\n")}"
        raise
      end
    end
    10.times do
      begin
        sleep 0.1
        response = Net::HTTP.start('127.0.0.1', '4567') do |http|
          http.get "/"
        end
        break
      rescue Errno::ECONNREFUSED
        retry
      end
    end
  end

  def teardown
    if @child
      Process.kill('KILL',@child)
      Process.waitpid(@child)
    end
    super
  end

  def test_to_params
    csv=CSV.parse(MyScript.new.run_script)
    assert_equal 2, csv.size
    assert_equal "get home page", csv[1][0]
    assert_equal "1", csv[1][2]
  end
end
