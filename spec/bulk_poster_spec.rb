require 'minitest/spec'
require 'minitest/pride'
require 'minitest/autorun'

require 'webmock/minitest'
require 'craigs_gem'

require 'nokogiri'

describe CraigsGem::BulkPoster do

  before do
    @account = {
      username: 'username@gmail.com',
      password: 'password',
      account_id: '14'
    }
    p1 = CraigsGem::Posting.new('NYCBrokerHousingSample1', {})
    p2 = CraigsGem::Posting.new('NYCBrokerHousingSample2', {})
    @poster = CraigsGem::BulkPoster.new(@account, [p1, p2])
  end

  it "must have account info" do
    @poster.account.must_be_instance_of Hash
    @poster.account[:username].must_equal 'username@gmail.com'
  end

  it "must have array of postings" do
    @poster.postings.must_be_instance_of Array
    @poster.postings.all? {|p| p.kind_of? CraigsGem::Posting}.must_equal true
  end

  describe "#check_postings_uniqness", "unique postings" do
    it "must accept postings with unique names" do
      a = CraigsGem::Posting.new('name', {})
      b = CraigsGem::Posting.new('unique_name', {})
      poster = CraigsGem::BulkPoster.new(@account, [a, b])
      poster.check_postings_uniqness
      poster.errors.must_be_empty
    end

    it "must NOT accept postings without unique names" do
      a = CraigsGem::Posting.new('name', {})
      b = CraigsGem::Posting.new('name', {})
      poster = CraigsGem::BulkPoster.new(@account, [a, b])
      poster.check_postings_uniqness
      poster.errors.wont_be_empty
    end
  end

  describe "#validate_postings", "validate postings" do
    it "must return TRUE if all the postings are valid" do
      a = Minitest::Mock.new
      b = Minitest::Mock.new
      c = Minitest::Mock.new
      poster = CraigsGem::BulkPoster.new(@account, [a, b, c])
      [a, b, c].each_with_index do |posting, i|
        posting.expect :validate!, nil
        posting.expect :name, "Sample#{i.to_s}"
        posting.expect :errors, []
      end
      poster.validate_postings
      poster.errors.must_be_empty
      poster.postings.map(&:errors).flatten.must_be_empty
      [a, b, c].each(&:verify)
    end
  end

  describe "#create_rss", "it must create a vaid rss" do
    it "must create RSS feed" do
      required_1 = {
        title: '1 Br Charmer in Chelsea',
        description: 'posting body goes here',
        category: 'fee',
        area: 'atl',
        reply_email: {
          value: 'bulkuser1@bulkposterz.net',
          privacy: 'A',
          outside_contact_ok: 0,
          other_contact_info: 'xxx'
        }
      }
      optional_1 = {
          images: [
            {position: 7, base64_encoded_image: File.read('spec/data/sample_base64_encoded_image1.txt')}
          ],
          subarea: 'eat',
          neighborhood: 'Upper West Side',
          price: '4,000,000',
          map_location: {
            city: 'New York',
            state: 'NY',
            cross_street1: '23rd Street',
            cross_street2: '9th Avenue',
            latitude: '40.746492',
            longitude: '-74.001326'
          },
          po_number: 'Purchase Order 094122',
          housing_info: {
            price: '10,000,000',
            bedrooms: '10',
            sqft: '15,000',
            cats_ok: '0',
            dogs_ok: '1'
          },
          broker_info: {
            company_name: 'Joe Sample and Associates',
            fee_disclosure: '100,000'
          },
          job_info: {
            compensation: '1,000,000',
            partTime: '0',
            disability: '1'
          },
          auto_basics: {
            auto_bodytype: 'SUV',
            auto_drivetrain: 'fwd',
            auto_paint: 'black',
            auto_size: 'compact',
            auto_title_status: 'clean',
            auto_transmission: 'manual',
            auto_year: '2014',
            auto_trans_auto: '1'
          },
          events: {
            event_art: '0',
            event_career: '1'
          },
          forsale: {
            sale_condition: '3 yr old',
            sale_date_1: 'Jan 1'
          },
          generic: {
            contact_method: "email only",
            contact_name: "pras",
            contact_ok: "1"
          },
          housing_basics: {
            bathrooms: '9+',
            housing_type: 'condo',
            is_furnished: '1'
          },
          housing_terms: {rent_period: 'monthly'},
          job_basics: {
            company_name: 'Abc',
            is_forpay: '1'
          },
          personals: {
            pers_body_type_is: 'athletic',
            pers_diet_is: 'vegan'
          }
      }
      posting_1 = CraigsGem::Posting.new('valid1', required_1, optional_1)
      required_2 = {
        title: 'Spacious Sunny Studio in Upper West Side',
        description: 'posting body goes here',
        category: 'fee',
        area: 'nyc',
        reply_email: {
          value: 'bulkuser2@bulkposterz.net',
          privacy: 'P',
          outside_contact_ok: 1,
          other_contact_info: 'yyy'
        }
      }
      posting_2 = CraigsGem::Posting.new('valid2', required_2)

      poster = CraigsGem::BulkPoster.new(@account, [posting_1, posting_2])
      # First validate...
      poster.validate_postings
      poster.errors.must_be_empty
      poster.postings.map(&:errors).flatten.must_be_empty
      # Then, create the RSS!
      poster.create_rss
      poster.errors.must_be_empty
      poster.postings.map(&:errors).flatten.must_be_empty
      rss = Nokogiri::XML(poster.submission_rss)
      # the generic stuff
      rss.css('item').count.must_equal 2
      item = rss.at_css('item') # let's do all the checks with the first item

      # all required elements must be present
      item.at_css('title').text.must_equal '1 Br Charmer in Chelsea'
      item.at_css('description').text.wont_be_empty
      item.at_css('cl|category').text.wont_be_empty
      item.at_css('cl|area').text.wont_be_empty
      item.at_css('cl|replyEmail').text.must_equal 'bulkuser1@bulkposterz.net'
      item.at_css('cl|replyEmail').attr('privacy').must_equal 'A'

      # Optional elements if present, must also be valid
      item.at_css('cl|image').attr('position').must_equal "7"
      item.at_css('cl|image').text.must_equal File.read('spec/data/sample_base64_encoded_image1.txt')
      item.at_css('cl|subarea').text.must_equal 'eat'
      item.at_css('cl|neighborhood').text.wont_be_empty
      item.at_css('cl|price').text.wont_be_empty
      item.at_css('cl|mapLocation').attr('city').wont_be_empty
      item.at_css('cl|mapLocation').attr('latitude').wont_be_empty
      item.at_css('cl|mapLocation').attr('longitude').must_equal '-74.001326'
      item.at_css('cl|PONumber').text.must_equal 'Purchase Order 094122'
      item.at_css('cl|housingInfo').attr('price').wont_be_empty
      item.at_css('cl|housingInfo').attr('bedrooms').must_equal '10'
      item.at_css('cl|housingInfo').attr('catsOK').must_equal '0'
      item.at_css('cl|brokerInfo').attr('companyName').wont_be_empty
      item.at_css('cl|brokerInfo').attr('feeDisclosure').must_equal '100,000'
      item.at_css('cl|jobInfo').attr('compensation').wont_be_empty
      item.at_css('cl|jobInfo').attr('disability').must_equal '1'
      item.at_css('cl|auto_basics').attr('auto_bodytype').wont_be_empty
      item.at_css('cl|auto_basics').attr('auto_year').must_equal '2014'
      item.at_css('cl|auto_basics').attr('auto_trans_auto').must_equal '1'
      item.at_css('cl|events').attr('event_art').must_equal '0'
      item.at_css('cl|events').attr('event_career').wont_be_empty
      item.at_css('cl|forsale').attr('sale_condition').wont_be_empty
      item.at_css('cl|forsale').attr('sale_date_1').wont_be_empty
      item.at_css('cl|generic').attr('contact_method').wont_be_empty
      item.at_css('cl|generic').attr('contact_name').wont_be_empty
      item.at_css('cl|generic').attr('contact_ok').must_equal '1'
      item.at_css('cl|housing_basics').attr('bathrooms').must_equal '9+'
      item.at_css('cl|housing_basics').attr('housing_type').must_equal 'condo'
      item.at_css('cl|housing_basics').attr('is_furnished').must_equal '1'
      item.at_css('cl|housing_terms').attr('rent_period').must_equal 'monthly'
      item.at_css('cl|job_basics').attr('company_name').must_equal 'Abc'
      item.at_css('cl|job_basics').attr('is_forpay').must_equal '1'
      item.at_css('cl|personals').attr('pers_body_type_is').must_equal 'athletic'
      item.at_css('cl|personals').attr('pers_diet_is').must_equal 'vegan'
    end
  end # describe "#create_rss"

  describe "#validate_at_craigslist" do
    before do
      required_1 = {
        title: '1 Br Charmer in Chelsea',
        description: 'posting body goes here',
        category: 'fee',
        area: 'atl',
        reply_email: {
          value: 'bulkuser1@bulkposterz.net',
          privacy: 'A',
          outside_contact_ok: 0,
          other_contact_info: 'xxx'
        }
      }
      posting_1 = CraigsGem::Posting.new('NYCBrokerHousingSample1', required_1)
      @poster = CraigsGem::BulkPoster.new(@account, [posting_1])
      @poster.validate_postings
      @poster.errors.must_be_empty
      @poster.postings.map(&:errors).flatten.must_be_empty
      @poster.create_rss
    end

    it "must return valid response for valid submissions" do
      stub_request(:post, CraigsGem::BulkPoster::URLS['validate']).with(:body => @poster.submission_rss, :headers => {'Content-Type'=>'application/x-www-form-urlencoded'}).to_return(:status => 200, :body => File.read('spec/data/sample_response_validation.xml'))
      @poster.validate_at_craigslist
      @poster.errors.must_be_empty
      @poster.postings.map(&:craigslist_posting_status).wont_be_empty
      @poster.postings.each do |p|
        p.craigslist_posting_status.must_respond_to :preview_html
        p.craigslist_posting_status.must_respond_to :posted_status
        p.craigslist_posting_status.must_respond_to :posted_explanation

        p.craigslist_posting_status.wont_respond_to :posting_id
        p.craigslist_posting_status.wont_respond_to :posting_manage_url
      end
    end

    it "must log error when the validation fails" do
      stub_request(:post, CraigsGem::BulkPoster::URLS['validate']).with(:body => @poster.submission_rss, :headers => {'Content-Type'=>'application/x-www-form-urlencoded'}).to_return(:status => 403, :body => "")
      @poster.validate_at_craigslist
      @poster.errors.wont_be_empty
    end
  end

  describe "#post_to_craigslist" do
    before do
      required_1 = {
        title: '1 Br Charmer in Chelsea',
        description: 'posting body goes here',
        category: 'fee',
        area: 'atl',
        reply_email: {
          value: 'bulkuser1@bulkposterz.net',
          privacy: 'A',
          outside_contact_ok: 0,
          other_contact_info: 'xxx'
        }
      }
      posting_1 = CraigsGem::Posting.new('NYCBrokerHousingSample1', required_1)
      @poster = CraigsGem::BulkPoster.new(@account, [posting_1])
      @poster.validate_postings
      @poster.errors.must_be_empty
      @poster.postings.map(&:errors).flatten.must_be_empty
      @poster.create_rss
    end

    it "must return valid 'posted' response for valid submissions" do
      stub_request(:post, CraigsGem::BulkPoster::URLS['validate']).with(:body => @poster.submission_rss, :headers => {'Content-Type'=>'application/x-www-form-urlencoded'}).to_return(:status => 200, :body => File.read('spec/data/sample_response_validation.xml'))
      stub_request(:post, CraigsGem::BulkPoster::URLS['post']).with(:body => @poster.submission_rss, :headers => {'Content-Type'=>'application/x-www-form-urlencoded'}).to_return(:status => 200, :body => File.read('spec/data/sample_response_posting.xml'))
      # Validate first
      @poster.validate_at_craigslist
      @poster.errors.must_be_empty
      @poster.postings.map(&:craigslist_posting_status).wont_be_empty
      # And then submit
      @poster.post_to_craigslist
      @poster.errors.must_be_empty
      @poster.postings.map(&:craigslist_posting_status).wont_be_empty
      @poster.postings.each do |p|
        p.craigslist_posting_status.must_respond_to :preview_html
        p.craigslist_posting_status.must_respond_to :posted_status
        p.craigslist_posting_status.must_respond_to :posted_explanation
        p.craigslist_posting_status.must_respond_to :posting_id
        p.craigslist_posting_status.must_respond_to :posting_manage_url
      end
    end

    it "must log error when invalid postings are submitted" do
      stub_request(:post, CraigsGem::BulkPoster::URLS['validate']).with(:body => @poster.submission_rss, :headers => {'Content-Type'=>'application/x-www-form-urlencoded'}).to_return(:status => 200, :body => File.read('spec/data/sample_response_validation.xml'))
      # Let the validation succeed...
      @poster.validate_at_craigslist
      @poster.errors.must_be_empty
      stub_request(:post, CraigsGem::BulkPoster::URLS['post']).with(:body => @poster.submission_rss, :headers => {'Content-Type'=>'application/x-www-form-urlencoded'}).to_return(:status => 403, :body => "")
      # but the submission fail!
      @poster.post_to_craigslist
      @poster.errors.wont_be_empty
    end
  end # describe post to craigslist

end # describe
