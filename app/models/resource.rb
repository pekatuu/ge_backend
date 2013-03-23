class Resource < ActiveRecord::Base
  attr_accessible :name

  def self.all_name
    Resource.all.map &:name
  end
end
