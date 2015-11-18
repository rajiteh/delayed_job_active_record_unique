module Delayed
  module Backend
    module Base
      module ClassMethods
        alias_method :uj_old_enqueue, :enqueue

        class UniqueJob
          ERROR_NO_QUEUE = ":queue MUST be specified in the options or a method "\
                           "queue_name must exist in the object for unique_job enqueue."
          ERROR_BAD_ARGS = "'unique_job' must be one of: Hash with key 'attr', a Symbol "\
                           "or non blank String and must be supplied with enqueue options "\
                           "or provided via a method named `unique_job` in the enqueued class."

          attr_accessor :opts
          attr_accessor :key
          
          def initialize(opts)
            self.opts = opts

            if detect_unique_job!
              uj = self.opts[:unique_job]
              candidate = if uj.is_a?(Hash)
                            if uj[:attr].is_a?(Proc)
                              uj[:attr].call(opts[:payload_object])
                            else
                              get_value_of(uj[:attr]) unless uj[:attr].blank?
                            end
                          elsif (uj.is_a?(String) || uj.is_a?(Symbol))
                            get_value_of(uj) unless uj.blank?
                          elsif uj.is_a?(Proc)
                            uj.call(opts[:payload_object])
                          end

              raise ArgumentError.new ERROR_NO_QUEUE unless detect_queue_name!
              raise ArgumentError.new ERROR_BAD_ARGS if candidate.blank?

              self.key = "#{candidate}"
            else
              disable_unique_job!
            end
          end

          def get_value_of(attr)
            if opts[:payload_object].is_a? Delayed::PerformableMethod
              opts[:payload_object].object.send(attr)
            else
              opts[:payload_object].send(attr)
            end
          end

          def disable_unique_job!
            self.key = false
          end

          def require_unique?
            key != false
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
            Delayed::Job.ready_to_run('', Delayed::Worker.max_run_time).where(:unique_id => slugged_key)
          end

          def slugged_key
            @slugged_key ||= "#{opts[:queue]}_#{key}"
          end

          def detect_unique_job!
            self.opts.has_key?(:unique_job) ||
                (opts[:payload_object].respond_to? :unique_job) &&
                    (opts[:unique_job] = { attr: Proc.new { opts[:payload_object].unique_job } } ) &&
                    (detect_unique_job_replace! || true)


          end

          def detect_unique_job_replace!
            (opts[:payload_object].respond_to? :unique_job_replace?) &&
                (opts[:unique_job][:replace] = opts[:payload_object].unique_job_replace?)
          end

          def detect_queue_name!
            self.opts.has_key?(:queue) ||
                (opts[:payload_object].respond_to? :queue_name) &&
                    (opts[:queue] = opts[:payload_object].queue_name)
          end

          def enqueue_opts
            require_unique? ? opts.except(:unique_job).merge(unique_id: slugged_key) : opts
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
