require_relative 'test_helper'
module Risa  
class TestRisaData < Minitest::Test
  def setup
    Risa.reload  # Clear collections before each test
    # Reset data path to default
    Risa.configure(data_path: 'data')
  end

  def teardown
    Risa.reload  # Clean up after each test
  end

  def test_configure
    Risa.configure(data_path: 'custom_data')
    assert_equal 'custom_data', Risa.instance_variable_get(:@data_path)
  end

  def test_define_and_query
    Risa.define :test_model do
      from_array([{ id: 1 }])
    end
    assert_instance_of Query, Risa.query(:test_model)
  end

  def test_undefined_model_raises
    error = assert_raises(RuntimeError) { Risa.query(:undefined) }
    assert_equal "Collection undefined not defined. Use Risa.define :undefined to define it.", error.message
  end

  def test_reload
    Risa.define :test_model do
      from_array([])
    end
    Risa.reload
    assert_empty Risa.defined_models
  end

  def test_defined_models
    Risa.define :model1 do
      from_array([])
    end
    Risa.define :model2 do
      from_array([])
    end
    assert_equal [:model1, :model2], Risa.defined_models.sort
  end

  def test_global_helper
    Risa.define :test_model do
      from_array([{ id: 1 }])
    end
    
    # Test the global all() helper method
    assert_instance_of Query, all(:test_model)
  end
end
end