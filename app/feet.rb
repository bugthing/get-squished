class Feet
  FOOT_COUNT = 3

  def initialize(state)
    self.state = state
    self.state.feet ||= default_collection
  end

  attr_accessor :state

  def each_foot
    state.feet.each { |entity| yield(Foot.new(entity)) }
  end

  def default_collection
    all_new_feet.tap do |collection|
      prev_foot = nil
      collection.each do |entity|
        foot = Foot.new(entity)
        foot.defaults!(right_of: prev_foot)
        prev_foot = foot
      end
    end
  end

  def all_new_feet
    (0..(FOOT_COUNT - 1)).map { state.new_entity(:foot) }
  end
end
