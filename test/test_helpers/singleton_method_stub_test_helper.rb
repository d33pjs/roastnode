module SingletonMethodStubTestHelper
  private
    def with_stubbed_singleton_method(target, method_name, replacement)
      original = target.method(method_name)
      target.define_singleton_method(method_name, replacement)
      yield
    ensure
      target.define_singleton_method(method_name, original)
    end
end
