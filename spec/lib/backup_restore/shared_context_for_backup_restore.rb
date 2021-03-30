# frozen_string_literal: true
#
shared_context "shared stuff" do
  let!(:logger) do
    Class.new do
      def log(message, ex = nil); end

      def log_step(message, fail_on_error: false)
        yield
      end

      def log_error(message, ex); end
      def log_warning(message, ex = nil); end
    end.new
  end
end
