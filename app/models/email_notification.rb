module EmailNotification
  Verdict = Data.define(:action, :kind) do
    def self.skip          = new(action: :skip,    kind: nil)
    def self.enqueue(kind) = new(action: :enqueue, kind: kind)
  end
end
