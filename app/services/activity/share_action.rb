module Activity
  module ShareAction
    module_function

    def resolve(prefix:, was_new:, was_enabled:, enabled:)
      return enabled ? "#{prefix}.published" : "#{prefix}.created" if was_new
      return "#{prefix}.published" if !was_enabled && enabled
      return "#{prefix}.disabled" if was_enabled && !enabled

      "#{prefix}.updated"
    end
  end
end
