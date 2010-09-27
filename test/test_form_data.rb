require 'rubygems'
require 'nokogiri'
require 'test/unit'
require 'nokoload/form_data'

class TestFormData < Test::Unit::TestCase
  def test_to_params
    fd=Nokoload::Runner::FormData.new({"abc" => [{"a" => "1", "b" => "2"}, {"a" => "2", "b" => "0"}], "h" => {"q" => 1, "w" => 2}})
    assert_equal "abc[][a]=1&abc[][b]=2&abc[][a]=2&abc[][b]=0&h[q]=1&h[w]=2", fd.to_params
  end
  
  def test_add_param_simple
    fd=Nokoload::Runner::FormData.new({})
    fd.add_param "abc",1
    assert_equal({"abc"=>1}, fd.form_data)
  end

  def test_add_param_array
    fd=Nokoload::Runner::FormData.new({})
    fd.add_param "abc[]",1
    assert_equal({"abc"=>[1]}, fd.form_data)
    fd.add_param "abc[]", 2
    assert_equal({"abc"=>[1, 2]}, fd.form_data)
  end
  
  def test_add_param_hash
    fd=Nokoload::Runner::FormData.new({})
    fd.add_param "abc[a]",1
    assert_equal({"abc"=>{"a" => 1}}, fd.form_data)
    fd.add_param "abc[b]", 2
    assert_equal({"abc"=>{"a" => 1, "b" => 2}}, fd.form_data)
  end
  
  def test_add_param_complex_array
    fd=Nokoload::Runner::FormData.new({})
    fd.add_param "outer[abc][][a]",1
    assert_equal({"outer" => {"abc"=>[{"a" => 1}]}}, fd.form_data)
    fd.add_param "outer[abc][][b]",2
    assert_equal({"outer" => {"abc"=>[{"a" => 1, "b" => 2}]}}, fd.form_data)
  end
  
  def test_fill_values_by_labels
    fd=Nokoload::Runner::FormData.new({},Nokogiri::HTML(IO.read(File.dirname(__FILE__)+"/form.html")))
    fd.fill_values_by_labels({"Expected velocity" => 20, "Burnup height" => 12, "Roles" => "developer"}).add_form
    assert_equal({"product"=>
                   {"expected_velocity"=>"20",
                     "burnup_height"=>"12",
                     "milestones_attributes"=>
                     {"0"=>{"name"=>"", "date_of_milestone"=>""},
                       "1"=>{"name"=>"", "date_of_milestone"=>""}}},
                   "roles"=>[{"role_id"=>"1710984090", "user_id"=>nil}, {"role_id"=>nil, "user_id"=>nil}]}, fd.form_data)
  end
end
