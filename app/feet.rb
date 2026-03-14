class Feet
  FOOT_COUNT   = 3
  MAX_FEET     = 20
  SPAWN_EVERY  = 20  # seconds

  def initialize(state)
    self.state       = state
    self.state.feet ||= default_collection
  end

  attr_accessor :state

  def each_foot
    state.feet.each { |entity| yield(Foot.new(entity)) }
  end

  def update_count(score_seconds)
    target = [FOOT_COUNT + (score_seconds / SPAWN_EVERY), MAX_FEET].min
    while state.feet.length < target
      entity = state.new_entity(:foot)
      foot   = Foot.new(entity)
      last   = Foot.new(state.feet.last)
      foot.defaults!(right_of: last)
      state.feet = state.feet + [entity]
    end
  end

  private

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
