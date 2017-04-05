require "spec_helper"
require "ood_core/job/adapters/lsf"

describe OodCore::Job::Adapters::Lsf do
  let(:batch) { double() }
  subject(:adapter) { described_class.new(batch: batch) }

  it { is_expected.to respond_to(:submit).with(0).arguments.and_keywords(:script, :after, :afterok, :afternotok, :afterany) }
  it { is_expected.to respond_to(:info).with(0).arguments.and_keywords(:id) }
  it { is_expected.to respond_to(:status).with(0).arguments.and_keywords(:id) }
  it { is_expected.to respond_to(:hold).with(0).arguments.and_keywords(:id) }
  it { is_expected.to respond_to(:release).with(0).arguments.and_keywords(:id) }
  it { is_expected.to respond_to(:delete).with(0).arguments.and_keywords(:id) }

  describe "#submit" do
    def build_script(opts = {})
      OodCore::Job::Script.new(
        {
          content: content
        }.merge opts
      )
    end

    # override existing batch var so when adapter is instantiated
    # we get an adapter with this batch object
    let(:batch) { double(submit_string: "job.123") }
    let(:content) { "my batch script" }

    context "with script" do
      before { adapter.submit(script: build_script()) }

      it { expect(batch).to have_received(:submit_string).with(content, args: [], env: {}) }
    end

    context "with :accounting_id" do
      before { adapter.submit(script: build_script(accounting_id: "my_account")) }

      it { expect(batch).to have_received(:submit_string).with(content, args: ["-P", "my_account"], env: {}) }
    end

    context "with :workdir" do
      before { adapter.submit(script: build_script(workdir: "/path/to/workdir")) }

      #TODO: LSF 9+ support handle case where workdir is set to a string with dynamic parameters
      #i.e. "/home/efranz/scratch/%J_%I" then make sure we don't need something like
      #expect...with(content, args: ["-cwd", '"/home/efranz/scratch/%J_%I"'])
      #notice the parenthesis being part of the command

      it { expect(batch).to have_received(:submit_string).with(content, args: ["-cwd", "/path/to/workdir"], env: {}) }
    end

    context "with :job_name" do
      before { adapter.submit(script: build_script(job_name: "my_job")) }

      it { expect(batch).to have_received(:submit_string).with(content, args: ["-J", "my_job"], env: {}) }
    end

    context "when OodCore::Job::Adapters::Lsf::Batch::Error is raised" do
      before { expect(batch).to receive(:submit_string).and_raise(OodCore::Job::Adapters::Lsf::Batch::Error) }

      it "raises OodCore::JobAdapterError" do
        expect { adapter.submit(script: build_script()) }.to raise_error(OodCore::JobAdapterError)
      end
    end
  end

  # TODO: tests to add:
  # queued job
  # running job
  # when can't find job, status complete
  # when can find job and status is EXIT or DONE, status complete
  describe "#status and #info" do
    # TODO: do we create a complex mock?
    let(:batch) { double(get_jobs: [running_job_hash]) }

    #FIXME: using the filters to select specific fields, we can ensure that this doesn't change
    #as LSF::Batch support more attributes
    let(:running_job_hash) {
      {
        id: "542935",
        user: "efranz",
        status: "RUN",
        queue: "short",
        from_host: "foobar02.osc.edu",
        exec_host: "compute013",
        name: "foo",
        submit_time: "03/31-14:46:42",
        project: "default",
        cpu_used: "000:00:00.00",
        mem:"2",
        swap:"32",
        pids:"25156",
        start_time: "03/31-14:46:44",
        finish_time: nil
      }
    }

    describe "#status" do
      it "returns running status" do
        expect(adapter.status(id: "542935")).to eq(OodCore::Job::Status.new(state: :running))
      end
    end
  end
end
