require 'minitest/spec'
require 'minitest/pride'
require 'minitest/autorun'

require 'craigs_gem'

describe CraigsGem::Posting do
  
  before do
    opts = {}
    @posting = CraigsGem::Posting.new('name', opts)
  end

  it "must have a name" do
    @posting.name.must_equal 'name'
  end

  describe "#validate!" do
    it "must NOT accept postings without the required elements" do
      invalid_required = {}
      posting = CraigsGem::Posting.new('invalid', invalid_required)
      posting.validate!
      posting.errors.wont_be_empty
    end

    it "must only accept postings with all the required elements present and valid" do
      required = {
        title: '1 Br Charmer in Chelsea',
        description: 'posting body goes here',
        category: 'fee',
        area: 'atl',
        reply_email: {
          value: 'bulkuser@bulkposterz.net',
          privacy: 'P',
          outside_contact_ok: 1,
          other_contact_info: 'yyy'
        }
      }
      posting = CraigsGem::Posting.new('valid', required)
      posting.validate!
      posting.errors.must_be_empty
    end
  end

  describe "Validate optional items" do
    before do
      @required = {
        title: '1 Br Charmer in Chelsea',
        description: 'posting body goes here',
        category: 'fee',
        area: 'atl',
        reply_email: {
          value: 'bulkuser@bulkposterz.net',
          privacy: 'P',
          outside_contact_ok: 1,
          other_contact_info: 'yyy'
        }
      }
    end

    it "must not allow unknown optionals" do
      optional = {
        unknown: "who am I?",
        me_too: "I'm a spy"
      }
      posting = CraigsGem::Posting.new('optional', @required, optional)
      posting.validate_required_items
      posting.errors.must_be_empty
      posting.check_allowed_optionals
      posting.errors.wont_be_empty
    end

    describe "#validate_images" do
      it "must have valid images, if present" do
        optional = {
          images: [
            {position: 0, base64_encoded_image: File.read('spec/data/sample_base64_encoded_image1.txt')},
            {position: 1, base64_encoded_image: File.read('spec/data/sample_base64_encoded_image2.txt')}
          ]
        }
        posting = CraigsGem::Posting.new('optional', @required, optional)
        posting.optional_items[:images].must_be_instance_of Array
        posting.validate_required_items
        posting.errors.must_be_empty
        posting.validate_images
        posting.errors.must_be_empty
      end
      it "must have valid positions for images, if present" do
        optional = {
          images: [
            {base64_encoded_image: File.read('spec/data/sample_base64_encoded_image1.txt')},
            {position: 23, base64_encoded_image: File.read('spec/data/sample_base64_encoded_image2.txt')},
            {position: 24, base64_encoded_image: File.read('spec/data/sample_base64_encoded_image2.txt')}
          ]
        }
        posting = CraigsGem::Posting.new('optional', @required, optional)
        posting.validate_required_items
        posting.errors.must_be_empty
        posting.validate_images
        posting.errors.wont_be_empty
      end
    end # validate images

    describe "#validate_subarea" do
      it "must have valid subarea, if present" do
        optional = {
          subarea: 'eat'
        }
        posting = CraigsGem::Posting.new('optional', @required, optional)
        posting.validate_required_items
        posting.errors.must_be_empty
        posting.validate_subarea
        posting.errors.must_be_empty
      end
    end
  end # validate optional

end # describe
