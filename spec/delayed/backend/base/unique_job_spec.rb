require 'helper'

describe Delayed::Backend::Base::ClassMethods::UniqueJob do
  subject { Delayed::Backend::Base::ClassMethods::UniqueJob }

  let(:payload_object) { double(unique_prop: 99) }
  let(:queue_name) { 'test_queue' }

  describe '#attr' do

    shared_examples(:gets_attr) do
      it { expect(unique_job.attr).to eq "unique_prop" }
    end

    shared_context(:fails_to_get_attr) do
      it { expect{unique_job.attr}.to raise_error(ArgumentError)}
    end

    context 'options passed as a hash' do

      let(:unique_job) do
        subject.new payload_object: payload_object,
                      queue: queue_name,
                      unique_job: {
                          attr: :unique_prop
                      }
      end

      it_behaves_like :gets_attr

    end


    context 'options passed directly' do

      let(:unique_job) do
        subject.new payload_object: payload_object,
                    queue: queue_name,
                    unique_job: :unique_prop
      end

      it_behaves_like :gets_attr

    end

    context 'blank opts' do
      let(:unique_job) do
        subject.new payload_object: payload_object,
                    queue: queue_name,
                    unique_job: ''
      end

      it_behaves_like :fails_to_get_attr

    end

    context 'incorrect opts' do
      let(:unique_job) do
        subject.new payload_object: payload_object,
                    queue: queue_name,
                    unique_job: { }
      end

      it_behaves_like :fails_to_get_attr

    end

    context 'custom class with queue definition' do
      let(:unique_job) do
        job_id = 'abcdef'
        cj = CustomJob.new(job_id)
        cj.queue_name= 'class_queue'
        subject.new payload_object: cj,
                    unique_job: :unique_prop
      end

      it_behaves_like :gets_attr
    end

    context 'no queue' do

      it do
        opts = {payload_object: payload_object, unique_job: :unique_prop}
        expect{subject.new opts}.to raise_error(ArgumentError)
      end

    end

  end

  describe '#require_unique?' do
    context 'unique job not specified' do

      let(:unique_job) do
        subject.new payload_object: payload_object,
                    queue: queue_name
      end

      it { expect(unique_job.require_unique?).to be false }

    end

    context 'unique job specified' do

      let(:unique_job) do
        subject.new payload_object: payload_object,
                    queue: queue_name,
                    unique_job: 'kek'
      end

      it { expect(unique_job.require_unique?).to be true }

    end
  end

  describe '#replace_job?' do
    context 'defaults to false' do
      let(:unique_job) do
        subject.new payload_object: payload_object,
                    queue: queue_name,
                    unique_job: 'kek'
      end

      it { expect(unique_job.replace_job?).to be false }

    end

    context 'optionally false' do
      let(:unique_job) do
        subject.new payload_object: payload_object,
                    queue: queue_name,
                    unique_job: { attr: 'kek', replace: false }
      end

      it { expect(unique_job.replace_job?).to be false }

    end

    context 'optionally true' do
      let(:unique_job) do
        subject.new payload_object: payload_object,
                    queue: queue_name,
                    unique_job:  { attr: 'kek', replace: true }
      end

      it { expect(unique_job.replace_job?).to be true }

    end
  end

  describe '#can_proceed?' do
    context 'on unique job is not needed' do
      let(:unique_job) do
        subject.new payload_object: payload_object,
                    queue: queue_name
      end

      it { expect(unique_job.can_proceed?).to be true }
    end

    context 'on replace' do
      let(:unique_job) do
        subject.new payload_object: payload_object,
                    queue: queue_name,
                    unique_job: { attr: :unique_prop, replace: true }
      end

      before { unique_job.stub_chain(:ready_to_run_uniquely, :destroy_all) }
      it do
        expect(unique_job.ready_to_run_uniquely).to receive(:destroy_all)
        unique_job.can_proceed?.should be true
      end

    end

    context 'on ignore' do
      let(:unique_job) do
        subject.new payload_object: payload_object,
                    queue: queue_name,
                    unique_job: :unique_prop
      end
      context 'exists' do
        before { unique_job.stub_chain(:ready_to_run_uniquely, :exists?) { true } }

        it { expect(unique_job.can_proceed?).to be false }
      end

      context 'not exists' do
        before { unique_job.stub_chain(:ready_to_run_uniquely, :exists?) { false } }

        it { expect(unique_job.can_proceed?).to be true }
      end

    end


  end

  describe '#ready_to_run_uniquely' do

    let(:stories) do
      Story.class_eval do
        handle_asynchronously :whatever,
                              queue: 'test_queue',
                              unique_job: { attr: :story_id, replace: true }
      end
      (1..5).map { |n| Story.create!(text: "Story_#{n}") }
    end

    it 'there should only be one result' do
      stories.each { |s| s.whatever; s.whatever; }
      unique_job = subject.new payload_object: stories[3], queue: 'test_queue', unique_job: :story_id
      expect(unique_job.ready_to_run_uniquely.count).to be 1
    end

    it 'uses delayed job active record finder method' do
      Delayed::Job.stub(:ready_to_run) { double(:where => double(:destroy_all => true ) ) }
      unique_job = subject.new payload_object: stories[3], queue: 'test_queue', unique_job: :story_id
      expect(Delayed::Job).to receive(:ready_to_run)
      unique_job.ready_to_run_uniquely
    end

    after do
      Story.delete_all
      Delayed::Job.delete_all
    end
  end

  describe '#generate_key' do
    context 'PerformableMethod' do
      let(:story) do
        Story.class_eval do
          handle_asynchronously :whatever,
                                queue: 'test_queue',
                                unique_job: { attr: :story_id, replace: true }
        end
        Story.create!(text: "Story")
      end

      it do
        story.whatever
        expect(Delayed::Job.last.unique_id).to eq "test_queue_#{story.story_id}"
      end

      after do
        Story.delete_all
        Delayed::Job.delete_all
      end
    end

    context 'custom class' do
      it do
        job_id = 'abcdef'
        Delayed::Job.enqueue CustomJob.new(job_id), queue: 'test_queue', unique_job: :custom_job_id
        expect(Delayed::Job.last.unique_id).to eq "test_queue_#{job_id}"
      end

      after do
        Delayed::Job.delete_all
      end

    end

    context 'custom class with queue definition' do
      it do
        job_id = 'abcdef'
        cj = CustomJob.new(job_id)
        cj.queue_name= 'class_queue'
        Delayed::Job.enqueue cj, unique_job: :custom_job_id
        expect(Delayed::Job.last.unique_id).to eq "#{cj.queue_name}_#{job_id}"
      end

      after do
        Delayed::Job.delete_all
      end
    end


  end

end
