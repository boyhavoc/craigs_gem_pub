module CraigsGem
  class BulkPoster

    URLS = YAML.load_file "config/urls.yml"

    attr_reader :account, :postings, :errors, :submission_rss

    def initialize(account, postings)
      @errors = []
      @account = account
      @postings = postings
    end

    # Validations ########################

    def validate!
      validate_postings
      validate_at_craigslist
    end

    def validate_postings
      check_postings_uniqness
      @postings.each(&:validate!)
    end

    def validate_at_craigslist
      create_rss unless @submission_rss
      code, response = http_post(URLS['validate'])
      case code
      when "403"
        log_error(MSG_SUBMISSION_FAILED, response)
      when "415"
        log_error(MSG_SUBMISSION_PARSE_FAILED, response)
      when "200"
        parse_validation_response(response)
      end
    end

    def post_to_craigslist
      create_rss unless @submission_rss
      code, response = http_post(URLS['post'])
      case code
      when "403"
        log_error(MSG_SUBMISSION_FAILED, response)
      when "415"
        log_error(MSG_SUBMISSION_PARSE_FAILED, response)
      when "200"
        parse_posting_response(response)
      end
    end

    def parse_validation_response(res)
      doc = Nokogiri::XML res
      doc.css('item').each do |item|
        name =  item.attributes['about'].value
        preview_html = item.css('cl|previewHTML').text
        posted_status =  item.css('cl|postedStatus').text
        posted_explanation =  item.css('cl|postedExplanation').text
        posting = @postings.find { |p| p.name == name }
        next unless posting
        posting.craigslist_posting_status = OpenStruct.new(
          preview_html: preview_html,
          posted_status: posted_status,
          posted_explanation: posted_explanation
        )
      end
    end

    def parse_posting_response(res)
      doc = Nokogiri::XML res
      doc.css('item').each do |item|
        name = item.attributes['about'].value
        preview_html = item.css('cl|previewHTML').text
        posting_id = item.css('cl|postingID').text
        posted_status = item.css('cl|postedStatus').text
        posting_manage_url = item.css('cl|postingManageURL').text
        posted_explanation = item.css('cl|postedExplanation').text
        posting = @postings.find { |p| p.name == name }
        next unless posting
        posting.craigslist_posting_status = OpenStruct.new(
          posting_id: posting_id,
          preview_html: preview_html,
          posted_status: posted_status,
          posting_manage_url: posting_manage_url,
          posted_explanation: posted_explanation
        )
      end
    end

    def http_post(url)
      uri = URI(url)
      req = Net::HTTP::Post.new(uri)
      req['Content-Type'] = "application/x-www-form-urlencoded"
      req.body = @submission_rss
      res = nil
      Net::HTTP.start(uri.host, uri.port, use_ssl: (uri.scheme=='https')) do |h|
        res = h.request req
      end
      [res.code, res.body]
    end

    # RSS Creation ########################

    def create_rss
      builder = Nokogiri::XML::Builder.new do |xml|
        xmlns_stuff = {
          xmlns: "http://purl.org/rss/1.0/",
          "xmlns:rdf" => "http://www.w3.org/1999/02/22-rdf-syntax-ns#",
          "xmlns:cl" => "http://www.craigslist.org/about/cl-bulk-ns/1.0"
        }
        xml['rdf'].RDF(xmlns_stuff) do
          rss_create_channel(xml)
          @postings.each { |posting| rss_create_item(xml, posting) }
        end
      end

      @submission_rss = builder.to_xml
    end

    def rss_create_channel(xml)
      xml.channel do
        xml.items do
          @postings.map(&:name).each { |name|
            xml['rdf'].li("rdf:resource" => name)
          }
        end
        auth_stuff = {
          username: @account[:username],
          password: @account[:password],
          accountID: @account[:account_id]
        }
        xml['cl'].auth(auth_stuff)
      end
    end

    def rss_create_item(xml, posting)
      xml.item("rdf:about" => posting.name) do
        rss_create_required_items(xml, posting.required_items)
        rss_create_optional_items(xml, posting.optional_items)
      end
    end
    
    def rss_create_required_items(xml, required)
      xml.title required[:title]
      xml.description { xml.cdata required[:description] }
      xml['cl'].category required[:category]
      xml['cl'].area required[:area]
      rss_create_reply_email(xml, required[:reply_email])
    end

    def rss_create_optional_items(xml, optional)
      rss_create_optional_images xml, optional[:images]
      rss_create_optional_subarea xml, optional[:subarea]
      rss_create_optional_neighborhood xml, optional[:neighborhood]
      rss_create_optional_price xml, optional[:price]
      rss_create_optional_map_location xml, optional[:map_location]
      rss_create_optional_po_number xml, optional[:po_number]
      rss_create_optional_housing_info xml, optional[:housing_info]
      rss_create_optional_broker_info xml, optional[:broker_info]
      rss_create_optional_job_info xml, optional[:job_info]
      rss_create_optional_auto_basics xml, optional[:auto_basics]
      rss_create_optional_events xml, optional[:events]
      rss_create_optional_forsale xml, optional[:forsale]
      rss_create_optional_generic xml, optional[:generic]
      rss_create_optional_housing_basics xml, optional[:housing_basics]
      rss_create_optional_housing_terms xml, optional[:housing_terms]
      rss_create_optional_job_basics xml, optional[:job_basics]
      rss_create_optional_personals xml, optional[:personals]
    end

    # Individual elements ################

    def rss_create_reply_email(xml, email)
      attrs = {
        privacy: email[:privacy],
        outsideContactOK: email[:outside_contact_ok],
        otherContactInfo: email[:other_contact_info]
      }
      attrs.delete_if { |_,v| v.nil? }
      xml['cl'].replyEmail(attrs) {
        xml.text email[:value]
      }
    end

    def rss_create_optional_images(xml, images)
      return if images.nil? or images.empty?
      images.each do |image|
        xml['cl'].image(position: image[:position]) {
          xml.text image[:base64_encoded_image]
        }
      end
    end

    def rss_create_optional_subarea(xml, subarea)
      return if subarea.nil?
      xml['cl'].subarea subarea
    end

    def rss_create_optional_neighborhood(xml, neighborhood)
      return if neighborhood.nil?
      xml['cl'].neighborhood neighborhood
    end

    def rss_create_optional_price(xml, price)
      return if price.nil?
      xml['cl'].price price
    end

    def rss_create_optional_map_location(xml, map)
      return if map.nil?
      attrs = {
        city: map[:city],
        state: map[:state],
        postal: map[:postal],
        crossStreet1: map[:cross_street1],
        crossStreet2: map[:cross_street2],
        latitude: map[:latitude],
        longitude: map[:longitude]
      }
      attrs.delete_if { |_,v| v.nil? }
      xml['cl'].mapLocation(attrs)
    end

    def rss_create_optional_po_number(xml, po_number)
      return if po_number.nil?
      xml['cl'].PONumber po_number
    end

    def rss_create_optional_housing_info(xml, housing_info)
      return if housing_info.nil? or housing_info.empty?
      attrs = {
        price: housing_info[:price],
        bedrooms: housing_info[:bedrooms],
        sqft: housing_info[:sqft],
        catsOK: housing_info[:cats_ok],
        dogsOK: housing_info[:dogs_ok]
      }
      attrs.delete_if { |_,v| v.nil? }
      xml['cl'].housingInfo(attrs)
    end

    def rss_create_optional_broker_info(xml, broker_info)
      return if broker_info.nil? or broker_info.empty?
      attrs = {
        companyName: broker_info[:company_name],
        feeDisclosure: broker_info[:fee_disclosure]
      }
      attrs.delete_if { |_,v| v.nil? }
      xml['cl'].brokerInfo(attrs)
    end

    def rss_create_optional_job_info(xml, info)
      return if info.nil? or info.empty?
      attrs = {
        compensation: info[:compensation],
        telecommuting: info[:telecommuting],
        partTime: info[:part_time],
        contract: info[:contract],
        nonprofit: info[:nonprofit],
        internship: info[:internship],
        disability: info[:disability],
        recruitersOK: info[:recruiters_ok],
        phoneCallsOK: info[:phone_calls_ok],
        okToContact: info[:ok_to_contact],
        okToRepost: info[:ok_to_repost]
      }
      attrs.delete_if { |_,v| v.nil? }
      xml['cl'].jobInfo(attrs)
    end

    def rss_create_optional_auto_basics(xml, auto)
      return if auto.nil? or auto.empty?
      attrs = {
        auto_bodytype: auto[:auto_bodytype],
        auto_drivetrain: auto[:auto_drivetrain],
        auto_fuel_type: auto[:auto_fuel_type],
        auto_make_model: auto[:auto_make_model],
        auto_miles: auto[:auto_miles],
        auto_paint: auto[:auto_paint],
        auto_size: auto[:auto_size],
        auto_title_status: auto[:auto_title_status],
        auto_trans_auto: auto[:auto_trans_auto],
        auto_trans_manual: auto[:auto_trans_manual],
        auto_transmission: auto[:auto_transmission],
        auto_vin: auto[:auto_vin],
        auto_year: auto[:auto_year]
      }
      attrs.delete_if { |_,v| v.nil? }
      xml['cl'].auto_basics(attrs)
    end

    def rss_create_optional_events(xml, events)
      return if events.nil? or events.empty?
      attrs = {
        event_art: events[:event_art],
        event_athletics: events[:event_athletics],
        event_career: events[:event_career],
        event_dance: events[:event_dance],
        event_festival: events[:event_festival],
        event_fitness_wellness: events[:event_fitness_wellness],
        event_food: events[:event_food],
        event_free: events[:event_free],
        event_fundraiser_vol: events[:event_fundraiser_vol],
        event_geek: events[:event_geek],
        event_kidfriendly: events[:event_kidfriendly],
        event_literary: events[:event_literary],
        event_music: events[:event_music],
        event_outdoor: events[:event_outdoor],
        event_sale: events[:event_sale],
        event_singles: events[:event_singles]
      }
      attrs.delete_if { |_,v| v.nil? }
      xml['cl'].events(attrs)
    end

    def rss_create_optional_forsale(xml, forsale)
      return if forsale.nil? or forsale.empty?
      attrs = {
        sale_condition: forsale[:sale_condition],
        sale_date_1: forsale[:sale_date_1],
        sale_date_2: forsale[:sale_date_2],
        sale_date_3: forsale[:sale_date_3],
        sale_size: forsale[:sale_size],
        sale_time: forsale[:sale_time]
      }
      attrs.delete_if { |_,v| v.nil? }
      xml['cl'].forsale(attrs)
    end

    def rss_create_optional_generic(xml, generic)
      return if generic.nil? or generic.empty?
      attrs = {
        contact_method: generic[:contact_method],
        contact_name: generic[:contact_name],
        contact_ok: generic[:contact_ok],
        contact_phone: generic[:contact_phone],
        contact_phone_ok: generic[:contact_phone_ok],
        contact_text_ok: generic[:contact_text_ok],
        fee_disclosure: generic[:fee_disclosure],
        has_license: generic[:has_license],
        license_info: generic[:license_info],
        phonecalls_ok: generic[:phonecalls_ok],
        repost_ok: generic[:repost_ok],
        see_my_other: generic[:see_my_other]
      }
      attrs.delete_if { |_,v| v.nil? }
      xml['cl'].generic(attrs)
    end

    def rss_create_optional_housing_basics(xml, housing)
      return if housing.nil? or housing.empty?
      attrs = {
        bathrooms: housing[:bathrooms],
        housing_type: housing[:housing_type],
        is_furnished: housing[:is_furnished],
        laundry: housing[:laundry],
        movein_date: housing[:movein_date],
        no_smoking: housing[:no_smoking],
        parking: housing[:parking],
        private_bath: housing[:private_bath],
        private_room: housing[:private_room],
        wheelchaccess: housing[:wheelchaccess]
      }
      attrs.delete_if { |_,v| v.nil? }
      xml['cl'].housing_basics(attrs)
    end

    def rss_create_optional_housing_terms(xml, terms)
      return if terms.nil? or terms.empty?
      attrs = {
        rent_period: terms[:rent_period]
      }
      attrs.delete_if { |_,v| v.nil? }
      xml['cl'].housing_terms(attrs)
    end

    def rss_create_optional_job_basics(xml, job)
      return if job.nil? or job.empty?
      attrs = {
        company_name: job[:company_name],
        disability_ok: job[:disability_ok],
        is_contract: job[:is_contract],
        is_forpay: job[:is_forpay],
        is_internship: job[:is_internship],
        is_nonprofit: job[:is_nonprofit],
        is_parttime: job[:is_parttime],
        is_telecommuting: job[:is_telecommuting],
        is_volunteer: job[:is_volunteer],
        recruiters_ok: job[:recruiters_ok],
        remuneration: job[:remuneration]
      }
      attrs.delete_if { |_,v| v.nil? }
      xml['cl'].job_basics(attrs)
    end

    def rss_create_optional_personals(xml, personals)
      p = personals
      return if p.nil? or p.empty?
      attrs = {
        pers_body_art_is: p[:pers_body_art_is],
        pers_body_type_is: p[:pers_body_type_is],
        pers_diet_is: p[:pers_diet_is],
        pers_dislikes_is: p[:pers_dislikes_is],
        pers_drinking_is: p[:pers_drinking_is],
        pers_drugs_is: p[:pers_drugs_is],
        pers_education_is: p[:pers_education_is],
        pers_ethnicity_is: p[:pers_ethnicity_is],
        pers_eyes_is: p[:pers_eyes_is],
        pers_facial_hair_is: p[:pers_facial_hair_is],
        pers_fears_is: p[:pers_fears_is],
        pers_freeform_answer_0_is: p[:pers_freeform_answer_0_is],
        pers_freeform_answer_1_is: p[:pers_freeform_answer_1_is],
        pers_freeform_answer_2_is: p[:pers_freeform_answer_2_is],
        pers_freeform_answer_3_is: p[:pers_freeform_answer_3_is],
        pers_freeform_answer_4_is: p[:pers_freeform_answer_4_is],
        pers_freeform_answer_5_is: p[:pers_freeform_answer_5_is],
        pers_freeform_answer_6_is: p[:pers_freeform_answer_6_is],
        pers_freeform_answer_7_is: p[:pers_freeform_answer_7_is],
        pers_freeform_question_0_is: p[:pers_freeform_question_0_is],
        pers_freeform_question_1_is: p[:pers_freeform_question_1_is],
        pers_freeform_question_2_is: p[:pers_freeform_question_2_is],
        pers_freeform_question_3_is: p[:pers_freeform_question_3_is],
        pers_freeform_question_4_is: p[:pers_freeform_question_4_is],
        pers_freeform_question_5_is: p[:pers_freeform_question_5_is],
        pers_freeform_question_6_is: p[:pers_freeform_question_6_is],
        pers_freeform_question_7_is: p[:pers_freeform_question_7_is],
        pers_hair_is: p[:pers_hair_is],
        pers_height_is: p[:pers_height_is],
        pers_interests_is: p[:pers_interests_is],
        pers_kids_has_is: p[:pers_kids_has_is],
        pers_kids_want_is: p[:pers_kids_want_is],
        pers_lang_native_is: p[:pers_lang_native_is],
        pers_likes_is: p[:pers_likes_is],
        pers_occupation_is: p[:pers_occupation_is],
        pers_personality_is: p[:pers_personality_is],
        pers_pets_is: p[:pers_pets_is],
        pers_politics_is: p[:pers_politics_is],
        pers_relationship_status_is: p[:pers_relationship_status_is],
        pers_religion_is: p[:pers_religion_is],
        pers_resembles_is: p[:pers_resembles_is],
        pers_smoking_is: p[:pers_smoking_is],
        pers_std_status_is: p[:pers_std_status_is],
        pers_weight_is: p[:pers_weight_is],
        pers_zodiac_is: p[:pers_zodiac_is]
      }
      attrs.delete_if { |_,v| v.nil? }
      xml['cl'].personals(attrs)
    end

    # Helpers ###########

    def check_postings_uniqness
      names = @postings.map(&:name)
      if names.length != names.uniq.length
        log_error(MSG_NONUNIQ_POSTINGS, "Postings must have unique names")
      end
    end

    def log_error(msg, value)
      final_msg = "#{msg}: '#{value}'"
      error = {
        type: :general,
        msg: final_msg
      }
      @errors << error
    end

  end # class
end # module
