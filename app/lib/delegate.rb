module Delegate
  def delegate(*attrs, to:)
    attrs.each do |attr|
      define_method(attr) do
        send(to).send(attr)
      end
      define_method("#{attr}=") do |*args|
        send(to).send("#{attr}=", *args)
      end
    end
  end
end
