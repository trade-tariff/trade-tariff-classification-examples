class LlmContext
  def initialize(client, system_prompt, user_prompt)
    @client = client
    @system_prompt = system_prompt
    @user_prompt = user_prompt
  end

  def call
    @client.call(self)
  end

  def self.build(context)
    client.call(context)
  end

  def self.client
    GeminiShellClient.new
  end
end
