module CraigsGem
  class Posting

    AREAS = YAML.load_file "config/areas.yml"
    CATEGORIES = YAML.load_file "config/categories.yml"
    AUTO_BASICS = YAML.load_file "config/auto_basics.yml"
    ALLOWED_OPTIONALS = YAML.load_file("config/optionals.yml")['allowed'].map(&:to_sym)

    AUTO_YEARS = ("1900".."2014").to_a
    GENERIC_CONTACT_METHODS = YAML.load_file "config/generic_contact_methods.yml"
    HOUSING_BASICS = YAML.load_file "config/housing_basics.yml"
    RENT_PERIOD = %w(daily monthly weekly yearly)
    EVENTS = YAML.load_file "config/events.yml"

    attr_reader :name, :required_items, :optional_items, :errors
    attr_accessor :craigslist_posting_status

    def initialize(name, required_items, optional_items={})
      @errors = []
      @name = name
      @required_items = required_items
      @optional_items = optional_items
    end

    def validate!
      validate_required_items
      validate_optional_items
    end

    def validate_required_items
      check_items_presence(
        where: @required_items,
        error_msg: MSG_REQUIRED_ELEMENT,
        items: [:title, :description, :category, :area, :reply_email]
      )
      validate_category
      validate_area
      validate_reply_email
    end

    def validate_optional_items
      check_allowed_optionals
      validate_images
      validate_subarea
      validate_job_info
      validate_auto_basics
      validate_generic
      validate_housing_basics
      validate_housing_terms
      validate_job_basics
      validate_events
    end

    # Validate required elements ################

    def validate_category
      category = @required_items[:category]
      unless CATEGORIES.map { |_,v| v.keys }.flatten.include?(category)
        attr_validation_error(:category, nil, category, "Must be one of #{CATEGORIES.map { |_,v| v.keys }.flatten}")
      end
    end

    def validate_area
      area = @required_items[:area]
      unless AREAS.keys.include?(area)
        attr_validation_error(:area, nil, area, "Must be one of #{AREAS.keys}")
      end
    end

    def validate_reply_email
      reply_email = @required_items[:reply_email]
      if reply_email.nil?
        log_error(MSG_REQUIRED_ELEMENT, 'ReplyEmail')
        return false
      end
      check_items_presence(
        where: reply_email,
        error_msg: "Invalid or empty email attribute",
        items: [:value, :privacy, :outside_contact_ok]
      )
      unless %w[A C P].include?(reply_email[:privacy])
        attr_validation_error(:replyEmail, :privacy, reply_email[:privacy], "Must be one of 'A', 'C', or 'P'}")
      end
      unless [0,1].include?(reply_email[:outside_contact_ok])
        attr_validation_error(:replyEmail, :outside_contact_ok, reply_email[:outside_contact_ok], "Must be one of 0 or 1}")
      end
    end


    # Validate optional elements ################

    def check_allowed_optionals
      not_allowed = @optional_items.keys.reject do |item|
        ALLOWED_OPTIONALS.include?(item)
      end
      return if not_allowed.empty?
      not_allowed.each do |unknown|
        log_error("Unknown element", unknown)
      end
    end

    def validate_images
      images = @optional_items[:images]
      return if images.nil? or images.empty?
      return unless images.is_a? Array
      images.each do |image|
        position = image[:position]
        next unless position
        unless position.between?(0, 23)
          attr_validation_error(:image, :position, image[:position], "Must be one of #{(0..23).to_a}")
        end
      end
    end

    def validate_subarea
      area = @required_items[:area]
      subarea = @optional_items[:subarea]
      return if subarea.nil?
      return unless AREAS.keys.include? area
      unless AREAS[area].keys.include?(subarea)
        attr_validation_error(:subarea, nil, subarea, "Must be one of #{AREAS[area].keys}")
      end
    end

    def validate_auto_basics
      auto = @optional_items[:auto_basics]
      return if auto.nil? or auto.empty?
      if auto[:auto_bodytype] && !AUTO_BASICS['auto_bodytype'].include?(auto[:auto_bodytype])
        attr_validation_error(:auto_basics, :auto_bodytype, auto[:auto_bodytype], "Must be one of #{AUTO_BASICS['auto_bodytype']}")
      end
      if auto[:auto_drivetrain] && !AUTO_BASICS['auto_drivetrain'].include?(auto[:auto_drivetrain])
        attr_validation_error(:auto_basics, :auto_drivetrain, auto[:auto_drivetrain], "Must be one of #{AUTO_BASICS['auto_drivetrain']}")
      end
      if auto[:auto_fuel_type] && !AUTO_BASICS['auto_fuel_type'].include?(auto[:auto_fuel_type])
        attr_validation_error(:auto_basics, :auto_fuel_type, auto[:auto_fuel_type], "Must be one of #{AUTO_BASICS['auto_fuel_type']}")
      end
      if auto[:auto_paint] && !AUTO_BASICS['auto_paint'].include?(auto[:auto_paint])
        attr_validation_error(:auto_basics, :auto_paint, auto[:auto_paint], "Must be one of #{AUTO_BASICS['auto_paint']}")
      end
      if auto[:auto_size] && !AUTO_BASICS['auto_size'].include?(auto[:auto_size])
        attr_validation_error(:auto_basics, :auto_size, auto[:auto_size], "Must be one of #{AUTO_BASICS['auto_size']}")
      end
      if auto[:auto_title_status] && !AUTO_BASICS['auto_title_status'].include?(auto[:auto_title_status])
        attr_validation_error(:auto_basics, :auto_title_status, auto[:auto_title_status], "Must be one of #{AUTO_BASICS['auto_title_status']}")
      end
      if auto[:auto_transmission] && !AUTO_BASICS['auto_transmission'].include?(auto[:auto_transmission])
        attr_validation_error(:auto_basics, :auto_transmission, auto[:auto_transmission], "Must be one of #{AUTO_BASICS['auto_transmission']}")
      end
      if auto[:auto_year] && !AUTO_YEARS.include?(auto[:auto_year])
        attr_validation_error(:auto_basics, :auto_year, auto[:auto_year])
      end
      bools = %w(auto_trans_auto auto_trans_manual)
      bools.map(&:to_sym).each do |attr|
        if auto[attr] && !%w(0 1).include?(auto[attr])
          attr_validation_error(:auto_basics, attr, auto[attr], "Must be one of '0' or '1'")
        end
      end
    end

    def validate_events
      events = @optional_items[:events]
      return if events.nil? or events.empty?
      EVENTS['events'].map(&:to_sym).each do |attr|
        if events[attr] && !%w(0 1).include?(events[attr])
          attr_validation_error(:events, attr, events[attr], "Must be one of '0' or '1'")
        end
      end
    end

    def validate_job_info
      job = @optional_items[:job_info]
      return if job.nil? or job.empty?
      bools = %w(telecommuting partTime contract nonprofit internship disability recruitersOK phoneCallsOK okToContact okToRepost)
      bools.map(&:to_sym).each do |attr|
        if job[attr] && !%w(0 1).include?(job[attr])
          attr_validation_error(:job_info, attr, job[attr], "Must be one of '0' or '1'")
        end
      end
    end
    
    def validate_generic
      generic = @optional_items[:generic]
      return if generic.nil? or generic.empty?
      if generic[:methods] && !GENERIC_CONTACT_METHODS['methods'].include?(generic[:contact_method])
        attr_validation_error(:generic, :methods, generic[:methods], "Must be one of #{GENERIC_CONTACT_METHODS['methods']}")
      end
      bools = %w(contact_ok contact_phone_ok contact_text_ok has_license phonecalls_ok repost_ok see_my_other)
      bools.map(&:to_sym).each do |attr|
        if generic[attr] && !%w(0 1).include?(generic[attr])
          attr_validation_error(:generic, attr, generic[attr], "Must be one of '0' or '1'")
        end
      end
    end

    def validate_housing_basics
      housing = @optional_items[:housing_basics]
      return if housing.nil? or housing.empty?
      if housing[:bathrooms] && !HOUSING_BASICS['bathrooms'].include?(housing[:bathrooms])
        attr_validation_error(:housing_basics, :bathrooms, housing[:bathrooms], "Must be one of #{HOUSING_BASICS['bathrooms']}")
      end
      bools = %w(is_furnished no_smoking private_bath private_room wheelchaccess)
      bools.map(&:to_sym).each do |attr|
        if housing[attr] && !%w(0 1).include?(housing[attr])
          attr_validation_error(:housing_basics, attr, housing[attr], "Must be one of '0' or '1'")
        end
      end
    end

    def validate_housing_terms
      terms = @optional_items[:housing_terms]
      return if terms.nil? or terms.empty?
      if terms[:rent_period] && !RENT_PERIOD.include?(terms[:rent_period])
        attr_validation_error(:housing_terms, :rent_period, terms[:rent_period], "Must be one of #{RENT_PERIOD}")
      end
    end

    def validate_job_basics
      job = @optional_items[:job_basics]
      return if job.nil? or job.empty?
      bools = %W(disability_ok is_contract is_forpay is_internship is_nonprofit is_parttime is_telecommuting is_volunteer recruiters_ok remuneration)
      bools.map(&:to_sym).each do |attr|
        if job[attr] && !%w(0 1).include?(job[attr])
          attr_validation_error(:job_basics, attr, job[attr], "Must be one of '0' or '1'")
        end
      end
    end

    # Helpers ###########

    def check_items_presence(opts)
      opts[:items].each { |item|
        unless opts[:where].key? item
          log_error(opts[:error_msg], item)
        end
      }
    end

    def log_error(msg, value)
      final_msg = "#{msg}: '#{value}'"
      error = {
        type: :general,
        msg: final_msg
      }
      @errors << error
    end

    def attr_validation_error(ele, attr, curr, must_be='')
      error = {
        type: :attr_validation_error,
        element: ele,
        attribute: attr,
        current_value: curr,
        must_be: must_be
      }
      @errors << error
    end

  end # class
end # module
