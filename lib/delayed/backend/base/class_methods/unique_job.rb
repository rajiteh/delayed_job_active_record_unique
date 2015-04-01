module Delayed
  module Backend
    module Base
      module ClassMethods
        alias_method :uj_old_enqueue, :enqueue

        class UniqueJob
          ERROR_NO_QUEUE = ":queue MUST be specified in the options or a method "\
                           "queue_name must exist in the object for unique_job enqueue."
          ERROR_BAD_ARGS = "'unique_job' must be one of: Hash with 'attr' key, a Symbol "\
                           "or non blank String."

          attr_accessor :opts
          def initialize(opts)
            self.opts = opts

            if self.opts.has_key?(:unique_job)
              self.opts[:queue] ||= class_queue_name #get class queue if specified
              raise ArgumentError.new ERROR_NO_QUEUE if opts[:queue].nil?
            else
              @attr = false
            end
          end

          def attr
            @attr ||= opts.has_key?(:unique_job) &&
                begin
                  candidate = opts[:unique_job].is_a?(Hash) ? opts[:unique_job][:attr] : opts[:unique_job]
                  if (candidate.is_a?(String) || candidate.is_a?(Symbol)) && !candidate.blank?
                    "#{candidate}"
                  else
                    raise ArgumentError.new ERROR_BAD_ARGS
                  end
                end
          end

          def require_unique?
            attr != false
          end

          def replace_job?
            opts[:unique_job].is_a?(Hash) &&
                opts[:unique_job][:replace] == true
          end

          def can_proceed?
            !require_unique? || if replace_job?
                                  ready_to_run_uniquely.destroy_all
                                  true
                                else
                                  !ready_to_run_uniquely.exists?
                                end
          end

          def ready_to_run_uniquely
            Delayed::Job.ready_to_run('', Delayed::Worker.max_run_time).where(:unique_id => generate_key)
          end

          def generate_key
            @key ||= if opts[:payload_object].is_a? Delayed::PerformableMethod
                       "#{opts[:queue]}_#{opts[:payload_object].object.send(attr)}"
                     else
                       "#{opts[:queue]}_#{opts[:payload_object].send(attr)}"
                     end
          end

          def class_queue_name
            unless opts[:payload_object].is_a? Delayed::PerformableMethod
              opts[:payload_object].queue_name if opts[:payload_object].respond_to? :queue_name
            end
          end
          def enqueue_opts
            require_unique? ? opts.except(:unique_job).merge(unique_id: generate_key) : opts
          end

        end

        def enqueue(*args)
          opts = args.extract_options!
          opts[:payload_object] ||= args.shift
          unique_job = UniqueJob.new opts
          unique_job.can_proceed? && uj_old_enqueue(unique_job.enqueue_opts)
        end

      end
    end
  end
end
