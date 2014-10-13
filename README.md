# CraigsGem

Ruby gem for [Craigslist bulk posting Interface](http://www.craigslist.org/about/bulk_posting_interface)

## Installation

Add this line to your application's Gemfile:

    gem 'craigs_gem'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install craigs_gem

### Note:

- Currently the gem is not available in Rubygems as this is built for commercial purpose.
- To build the gem, run `gem build craigs_gem.gemspec`. It will create a `craigs_gem-0.0.1.gem' file locally.
- Install the gem in your environment by running `gem install ./craigs_gem-0.0.1.gem`


## Usage

### The BulkPoster Class

The `CraigsGem::BulkPoster` object is used for bulk-posting to Craigslist.
It takes 2 parameters:

- `account` hash with craigslist `username`, `password` and `account_id` as keys,
- an array of postings objects that are of type `CraigsGem::Posting`


```ruby
require 'craigs_gem'

account = {
  username: 'sample@example.com',
  password: 'password',
  account_id: '14234'
}
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
optional = {
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
}
posting = CraigsGem::Posting.new("NYCBrokerHousingSample", required, optional)
poster = CraigsGem::BulkPoster.new(account, [posting])
```

Once the bulk poster object `poster` is setup, we can perform attribute validations, and craigslist https validation, and then actually publish all of the postings as well.

Attribute validation and Craigslist validation:
(notice you can access the preview html for each of the validated postings)

```ruby
# to perform attribute validation for all the postings
poster.validate_postings
if poster.errors.empty? && poster.postings.map(&:errors).flatten.empty?
  puts "No attribute validation errors!"
end

# to perform craigslist https validation
poster.validate_at_craigslist
if poster.errors.empty?
  poster.postings.each do |posting|
    puts posting.craigslist_posting_status.posted_status
    puts posting.craigslist_posting_status.posted_explanation
    puts posting.craigslist_posting_status.preview_html
  end
end
```

The submission RSS feed can be accessed after validation or by calling the `create_rss` method:

```ruby
poster.create_rss
puts poster.submission_rss
```

The validated RSS can be submitted to Craigslist for publishing, through the `post_to_craigslist` method:

```ruby
# (post only after performing validations)
poster.post_to_craigslist

# similar to validation status, posting status is available for each of the submitted posting:
poster.postings.each do |posting|
  puts posting.craigslist_posting_status.posted_status
  puts posting.craigslist_posting_status.posted_explanation
  puts posting.craigslist_posting_status.preview_html
  puts posting.craigslist_posting_status.posting_id
  puts posting.craigslist_posting_status.posting_manage_url
end
```

### The Posting Class

The `CraigsGem::Posting` object is used to define individual postings. It takes 3 arguments:

- `name` string,
- `required` - a hash of all the required elements,
- `optional` - a hash of all the optional elements 

The attributes of an element are represented as nested hashes within the element.

```ruby
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
optional = {
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
}
posting = CraigsGem::Posting.new("NYCBrokerHousingSample", required, optional)

```

A posting can be validated by the `validate!` method. It checks the attribute validations of all the possible required and optional elements.

```ruby
posting.validate!
if posting.errors.empty?
  puts "No attribute validation error for this posting!"
end
```

#### Required elements

These are the elements required to make a basic posting. This is the second argument for the `Posting` class:

- `:title` - title of the posting
- `:description` - description
- `category` - one of `CraigsGem::Posting::CATEGORIES.map { |_,v| v.keys }.flatten`
- `area` - one of `CraigsGem::Posting::AREAS.keys`
- `reply_email` - a hash with attributes as keys:
  - `value` - the actual email
  - `privacy` - one of 'A', 'C', or 'P'
  - `outside_contact_ok` - 0 or 1
  - `other_contact_info` - a string

#### Optional elements

The optional elements and their attributes are implemented in a similar manner. For a full list of the optional elements and their supported attributes, please refer the official [Craigslist bulk posting interface](http://www.craigslist.org/about/bulk_posting_interface)

## Tests

Run `rake test` to run the suite of Minitest examples.

Happy posting :)

## Contributing

1. Fork it ( https://github.com/[my-github-username]/craigs_gem/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
