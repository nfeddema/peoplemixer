require "#{Rails.root}/lib/code/schedule.rb"

class OperationsController < ApplicationController

  def home
  end

  def set
  end

  def display_form
  	@number_of_persons = params[:number_of_persons].to_i
    if @number_of_persons == 0
    	flash.now[:error] = 'Please enter a number'
      	render "set_quantity"
    else
    	render "display_form"
    end
  end

  def calculate
  	if valid_inputs_for_calculate? params
    	list_of_persons = params[:persons]
    	persons_per_group = params[:maximum_persons_per_group].to_i
    	number_of_rounds = params[:number_of_rounds].to_i
      times_to_run = params[:times_to_run].to_i

    	dsw = ScheduleDatasetWrapper.new(:seminarians_per_group => persons_per_group, :number_of_rounds => number_of_rounds, :seminarian_list => list_of_persons, :times_to_run => times_to_run)
    	@schedule_dataset = dsw.best_dataset
    	@groups = @schedule_dataset.groups.sort_by{|g| [g.position, g.day]}

      write_new_file @schedule_dataset

    	render "display_results"

    else
      @number_of_persons = params[:persons].count
      render "display_form"
    end
  end

  def download_file
    send_file(Rails.root + "tmp/schedule.txt")
  end

  private

    def valid_inputs_for_calculate? params
      if params[:maximum_persons_per_group].to_i == 0 || params[:number_of_rounds].to_i == 0 || params[:times_to_run].to_i == 0
        flash.now[:error] = 'Please enter numbers for "Persons per group," "Number of rounds," and "Times to run."'
        return false
      elsif any_persons_blank? params[:persons]
        flash.now[:error] = 'Please enter a name for each person.'
        return false
      elsif any_persons_identical? params[:persons]
        flash.now[:error] = 'Please enter a different name for each person.'
        return false
      else
        return true
      end
    end

    def any_persons_blank? persons
      persons.each do |p|
        return true if p.blank?
      end
      return false
    end

    def any_persons_identical? persons
      persons.uniq.count < persons.count
    end

    def write_new_file dataset
      File.open(Rails.root + "tmp/schedule.txt", "w") do |f|     
        f.write(dataset.print_to_string)
      end
    end
end
