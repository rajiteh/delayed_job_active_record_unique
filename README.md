[![Gem Version](https://badge.fury.io/rb/delayed_job_active_record_unique.svg)](http://badge.fury.io/rb/delayed_job_active_record_unique)
[![Build Status](https://travis-ci.org/rajiteh/delayed_job_active_record_unique.svg)](https://travis-ci.org/rajiteh/delayed_job_active_record_unique)
[![Coverage Status](https://coveralls.io/repos/rajiteh/delayed_job_active_record_unique/badge.svg)](https://coveralls.io/r/rajiteh/delayed_job_active_record_unique)
[![Dependency Status](https://gemnasium.com/rajiteh/delayed_job_active_record_unique.svg)](https://gemnasium.com/rajiteh/delayed_job_active_record_unique)

# DelayedJobActiveRecordUnique

This gem extends DelayedJob functionality by providing a simple interface to specify if the job being enqueued needs to
be unique within the queue.

## Motivation

Given a situation where a Job may overwrite some value every time it gets run (ie: batch imports), it makes 
sense to only keep the latest job on queue. DelayedJob provides named queues as a method to identify jobs however, 
using queue names to identify a large number of jobs is not feasible as the number of queues will grow  
and scaling will be difficult. This gem extends the DelayedJob table with a new column that will store a unique key 
from the handler thus will be able to detect if the specific job is already queued.

Example scenarios: Batching e-mail notifications or performing indexing tasks.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'delayed_job_active_record_unique'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install delayed_job_active_record_unique

If you're using Rails, run the generator to create the migration for the
delayed_job table.

    rails g delayed_job:active_record_unique
    rake db:migrate

## Usage

Uniqueness of the job can be specified by passing the key `unique_job` to the DelayedJob enqueue call. 

```ruby
    unique_job: {
        attr: :id # Required. A method name in the object that will be called to obtain a uniquely identifiable value.
        replace: true # Optional. Default = false. # Default behaviour will not enqueue a job that already exists.
                      # On true, Any job that is already queued under this unique ID will be replaced by the current.
    }
```

It is possible to just supply a `Symbol` to `unique_job` to set the attr value and proceed with default options.

*Note:* You must supply a `queue` name to enqueue options or via class method `queue_name` as the uniqueness is only global to the queue.  
## Example

If using `#handle_asynchronously`

```ruby
    handle_asynchronously :solr_index, queue: 'solr_indexing', priority: 50, unique_job: { attr: :id, replace: true }
```

If using a standalone class

```ruby
    Delayed::Job.enqueue NewsletterJob.new('lorem ipsum...', Customers.pluck(:email)), unique_job: :get_id
    #NewsLetterJob must have a 'get_id' method that will return a unique value to it's context.
```


## Contributing

1. Fork it ( https://github.com/rajiteh/delayed_job_active_record_unique/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
