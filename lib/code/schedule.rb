# New Strategy
# Revised per Father Tom's parameters

class Seminarian
  attr_accessor :name, :groups, :schedule_dataset
  
  def initialize args
    args.each do |k,v|
      instance_variable_set("@#{k}", v) unless v.nil?
    end
    @groups = []
  end
  
  def add_to_group group
    #puts "Adding #{self.name} to #{group}"
    self.groups.push(group)
    group.seminarians.push(self)
  end
  
  # Lesser scores indicate more compatibility
  def score_for_group group
    score = 0
    group.seminarians.each do |sem|
      # Exponential penalty
      if self.times_with_seminarian(sem) == 0
        score += 0
      else
        score += self.schedule_dataset.seminarians_per_group ** (self.times_with_seminarian(sem) - 1)
      end
    end
    
    return score
  end
  
  def times_with_seminarian sem
    return 0 if self.name == sem.name
    
    number_of_times = 0
    self.groups.collect{|x| x.seminarians}.flatten.each do |seminarian|
      number_of_times += 1 if sem.name == seminarian.name
    end
    
    return number_of_times
  end
  
  # Return groups seminarian is eligible for based on days_assigned
  def possible_groups groups
    possible_grps = groups.select {|g| !self.days_assigned.include?(g.day)}

    if possible_grps.count == 0 && self.duplicate_days < self.schedule_dataset.duplicate_days_allowed
      return groups

    # Return the groups with days that the seminarian has not been assigned to
    else
      return possible_grps
    end
  end

  # Return array of days seminarian has already been assigned to
  def days_assigned
    days_assigned = []
    self.groups.each {|g| days_assigned.push(g.day)}
    return days_assigned
  end

  # Return the number of duplicate days the seminarian has been assigned to
  def duplicate_days
    duplicates = 0
    dup_hash(self.days_assigned).each_value{|v| duplicates += v}
    return duplicates
  end

  def number_of_zeros
    count = 0
    self.schedule_dataset.seminarians.select{|s| s.name != self.name}.each do |sem|
      times = self.times_with_seminarian(sem)
      count += 1 if times == 0
    end
    
    return count
  end

  def number_of_singles
    count = 0
    self.schedule_dataset.seminarians.select{|s| s.name != self.name}.each do |sem|
      times = self.times_with_seminarian(sem)
      count += 1 if times == 1
    end
    
    return count
  end

  def number_of_doubles
    count = 0
    self.schedule_dataset.seminarians.select{|s| s.name != self.name}.each do |sem|
      times = self.times_with_seminarian(sem)
      count += 1 if times == 2
    end
    
    return count
  end
  
  def number_of_triples
    count = 0
    self.schedule_dataset.seminarians.select{|s| s.name != self.name}.each do |sem|
      times = self.times_with_seminarian(sem)
      count += 1 if times == 3
    end
    
    return count
  end

  def number_of_quad_plus
    count = 0
    self.schedule_dataset.seminarians.select{|s| s.name != self.name}.each do |sem|
      times = self.times_with_seminarian(sem)
      count += 1 if times > 3
    end
    
    return count
  end
end

class Group
  # Day corresponds to the group number within each round
  attr_accessor :position, :seminarians, :day, :schedule_dataset
  
  def initialize args
    args.each do |k,v|
      instance_variable_set("@#{k}", v) unless v.nil?
    end
    @seminarians = []
  end
  
  def full?
    self.seminarians.count >= self.schedule_dataset.seminarians_per_group
  end
end

class ScheduleDataset
  attr_accessor :seminarians, :groups, :round, :number_of_groups, :duplicate_days_allowed, :seminarians_per_group, :number_of_rounds

  def initialize args

    @seminarians = []
    @groups = []
    @round = 1
    @number_of_groups = nil
    @duplicate_days_allowed = nil
    # Eventually these should be required inputs
    @seminarians_per_group = 4
    @number_of_rounds = 4

    args.each do |k,v|
      if k == :seminarian_list
        prepopulate_seminarians v
      else
        instance_variable_set("@#{k}", v) unless v.nil?
      end
    end

    set_number_of_groups
    set_duplicate_days_allowed
    populate_groups
  end

  def seminarians_for_round i=@round
    # Select seminarians who belong to no group in the current round
    @seminarians.select do |sem|
      sem.groups.none?{|g| g.position == i}
    end
  end

  # Eventually we could look at every combination of sem and group, place the best one, then recalculate
  def populate_groups_for_round i=@round
    temp_groups = []
    (1..@number_of_groups).each_entry do |x|
      temp_group = Group.new(:position => i, :day => x, :schedule_dataset => self)
      temp_groups.push(temp_group)
    end

    # Add seminarians who need to be assigned to a single day
    seminarians_left = seminarians_for_round(i)
    seminarians_left.shuffle.each do |sem|
      possible_grps = sem.possible_groups(temp_groups)
      sem.add_to_group(possible_grps.first) if possible_grps.count == 1 && !possible_grps.first.full?
    end

    # Add seminarians with too many duplicates to a group with least number of seminarians
    seminarians_left = seminarians_for_round(i)
    seminarians_left.shuffle.each do |sem|
      possible_grps = sem.possible_groups(temp_groups).sort_by{|g| g.seminarians.count}
      sem.add_to_group(possible_grps.first) if sem.duplicate_days >= @duplicate_days_allowed && !possible_grps.first.full?
    end

    # Add at least one seminarian to each group
    seminarians_left = seminarians_for_round(i)
    seminarians_left.shuffle.each do |sem|
      possible_grps = sem.possible_groups(temp_groups).shuffle
      sem.add_to_group(possible_grps.first) if possible_grps.count < @number_of_groups && possible_grps.first.seminarians.count == 0
    end

    seminarians_left = seminarians_for_round(i)
    
    while seminarians_left.any? do

      #Find the smallest groups
      smallest_number = temp_groups.sort_by{|g| g.seminarians.count}.first.seminarians.count
      small_groups = temp_groups.select{|tg| tg.seminarians.count == smallest_number}

      best_match = nil
      best_score = 9000

      small_groups.shuffle.each do |group|
        seminarians_left.shuffle.each do |sem|
          
          #Find the best match of seminarians and small groups
          if sem.score_for_group(group) < best_score
            best_match = [sem, group]
            best_score = sem.score_for_group(group)
          end
        end
      end
      
      best_match.first.add_to_group(best_match.second) if best_match
      seminarians_left = seminarians_for_round(i)
    end
    
    temp_groups.each{|g| @groups.push(g)}
  end

  def populate_groups
    (1..@number_of_rounds).each do
      populate_groups_for_round
      @round += 1
    end
  end

  def prepopulate_seminarians sems
    sems.each do |seminarian|
      @seminarians.push(Seminarian.new(:name => seminarian, :schedule_dataset => self))
    end
  end

  def any_excess_duplicates?
    @seminarians.each {|s| return true if s.duplicate_days > @duplicate_days_allowed}
    return false
  end

  # Find the lowest number of duplicate days achieved by any one seminarian
  def most_duplicates
    highest = 0
    @seminarians.each {|s| highest = s.duplicate_days if s.duplicate_days > highest}
    return highest
  end

  def set_number_of_groups
    @number_of_groups = (@seminarians.count / @seminarians_per_group.to_f).ceil
  end

  # A seminarian can only be assigned to a day twice if this is necessary
  def set_duplicate_days_allowed
    @duplicate_days_allowed = @number_of_rounds - @number_of_groups
    @duplicate_days_allowed = 0 if @duplicate_days_allowed < 0
  end

  def smallest_group_size
    smallest = 9000
    @groups.each do |group|
      smallest = group.seminarians.count if group.seminarians.count < smallest
    end
    return smallest
  end

  #Find number of times seminarians went unpaired
  def number_of_zeros
    total_zeros = 0
    @seminarians.each do |sem|
      zeros = sem.number_of_zeros
      total_zeros += zeros
    end

    #Divide by 2 to correct the fact that each was counted twice
    return total_zeros/2
  end

  def number_of_singles
    total_singles = 0
    @seminarians.each do |sem|
      singles = sem.number_of_singles
      total_singles += singles
    end

    return total_singles/2
  end

  def number_of_doubles
    total_doubles = 0
    @seminarians.each do |sem|
      doubles = sem.number_of_doubles
      total_doubles += doubles
    end

    return total_doubles/2
  end

  def number_of_triples
    total_triples = 0
    @seminarians.each do |sem|
      triples = sem.number_of_triples
      total_triples += triples
    end

    return total_triples/2
  end

  def number_of_quad_plus
    total_quad_plus = 0
    @seminarians.each do |sem|
      quad_plus = sem.number_of_quad_plus
      total_quad_plus += quad_plus
    end

    return total_quad_plus/2
  end

  #Score for Dataset
  def score
    return number_of_triples + (number_of_zeros*2) + (number_of_quad_plus*3)
  end

  # Display Methods

  def print_to_string
    output = ''
    output << "Maximum persons per group: #{seminarians_per_group}\n"
    output << "Number of rounds: #{number_of_rounds}"

    ordered_groups = @groups.sort_by{|g| [g.position, g.day]}
    
    ordered_groups.each do |group|
      output << "\n\nRound #{group.position}, Section #{group.day}:"
      group.seminarians.each do |sem|
        output << "\n-#{sem.name}"
      end
    end
    return output
  end

  def print_groups
    ordered_groups = @groups.sort_by{|g| [g.position, g.day]}
    
    ordered_groups.each do |group|
      puts "\nGroup for round #{group.position}, day #{group.day}:"
      group.seminarians.each do |sem|
        puts "-#{sem.name}"
      end
    end
  end

  def print_success
    puts "\nTotal Zeros: #{number_of_zeros}"
    puts "Total Singles: #{number_of_singles}"
    puts "Total Doubles: #{number_of_doubles}"
    puts "Total Triples: #{number_of_triples}"
    puts "Total Quad Plus: #{number_of_quad_plus}"
    puts "Most Duplicates: #{most_duplicates}"
  end

  def print_days
    @seminarians.each do |sem|
      puts "#{sem.name} - #{sem.groups.collect{|g| g.day}} - #{sem.duplicate_days}"
    end
  end

  def print_score
    puts "Score: #{score}"
  end
end

class ScheduleDatasetWrapper
  attr_accessor :schedule_datasets, :seminarians_per_group, :number_of_rounds, :seminarian_list
  
  def initialize args
    args.each do |k,v|
      instance_variable_set("@#{k}", v) unless v.nil?
    end
    @schedule_datasets = []

    (1..1500).each do |i|
      @schedule_datasets.push(ScheduleDataset.new(:seminarians_per_group => @seminarians_per_group, :number_of_rounds => @number_of_rounds, :seminarian_list => @seminarian_list))
      #puts "...working...#{i}"
    end

    #Remove results that didn't achieve optimal quantity of duplicates
    least_dupes = self.least_duplicates
    @schedule_datasets = @schedule_datasets.select{|ds| ds.most_duplicates == least_dupes}
    #Remove results that include groups that are too small
    evenly_distributed = @schedule_datasets.select{|ds| ds.smallest_group_size >= ((ds.seminarians.count / ds.number_of_groups.to_f).floor)}
    @schedule_datasets = evenly_distributed if evenly_distributed.any?
    
    # Printing options
    best_dataset.print_groups
    #best_dataset.print_success
    #puts "\nBest Score: #{best_dataset.score}"
    #puts "#{@schedule_datasets.count} Datasets Found"
  end

  #Find the least number of duplicate days in a wrapper
  def least_duplicates
    smallest = 1000
    @schedule_datasets.each do |ds|
      smallest = ds.most_duplicates if ds.most_duplicates < smallest
    end
    return smallest
  end

  def best_dataset
    smallest = 9000
    winning_dataset = nil
    @schedule_datasets.each do |ds|
      if ds.score < smallest
        smallest = ds.score 
        winning_dataset = ds
      end
    end
    return winning_dataset
  end
end

# Returns a hash with each duplicated element and the number of times duplicated -- found online
def dup_hash(ary)
  new_hash = ary.inject(Hash.new(0)) { |h,e| h[e] += 1; h }.select { |_k,v| v > 1 }.inject({}) { |r, e| r[e.first] = e.last; r }
  new_hash.each{ |k,v| new_hash[k] = v - 1}
  return new_hash
end

sems = ['Ryan Andrew', 'Matthew Shireman', 'Tim Tran', 
  'TJ McKenzie', 'Jhonatan Sarmiento', 'Beau Braun', 
  'Tim Cone', 'Matt Quail', 'Grant Lacey', 'Neil Bakker', 
  'Jason Raftis', 'Ryan Welch', 'Jeff Baustian',
  'Joseph Wright', 'Paul Carlson', 'Andrew Dieter',
  'John Powers', 'Jeremy Bock', 'Nic Feddema', 'Steve Nolan']

semsx = ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'l', 'm', 'n',
  'o', 'p', 'q', 'r', 's', 't', 'u', 'v']

  
#dsw = ScheduleDatasetWrapper.new(:seminarians_per_group => 5, :number_of_rounds => 5, :seminarian_list => sems)

# require './lib/code/schedule.rb'