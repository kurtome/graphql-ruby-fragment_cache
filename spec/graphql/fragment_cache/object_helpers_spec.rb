# frozen_string_literal: true

require "spec_helper"

describe "#cache_fragment" do
  let(:schema) do
    field_resolver = resolver

    build_schema do
      query(
        Class.new(Types::Query) {
          field :post, Types::Post, null: true do
            argument :id, GraphQL::Types::ID, required: true
            argument :expires_in, GraphQL::Types::Int, required: false
          end

          define_method(:post, &field_resolver)
        }
      )
    end
  end

  let(:expires_in) { nil }
  let(:variables) { {id: 1, expires_in: expires_in} }

  let(:query) do
    <<~GQL
      query getPost($id: ID!, $expiresIn: Int) {
        post(id: $id, expiresIn: $expiresIn) {
          id
          title
        }
      }
    GQL
  end

  let!(:post) { Post.create(id: 1, title: "object test") }

  before do
    # warmup cache
    execute_query
    # make object dirty
    post.title = "new object test"
  end

  context "when block is passed" do
    let(:resolver) do
      ->(id:, expires_in:) do
        cache_fragment { Post.find(id) }
      end
    end

    it "returns cached fragment" do
      expect(execute_query.dig("data", "post")).to eq({
        "id" => "1",
        "title" => "object test"
      })
    end
  end

  context "when object is passed" do
    let(:resolver) do
      ->(id:, expires_in:) do
        post = Post.find(id)
        cache_fragment(post, expires_in: expires_in)
      end
    end

    it "returns cached fragment" do
      expect(execute_query.dig("data", "post")).to eq({
        "id" => "1",
        "title" => "object test"
      })
    end

    context "when :expires_in is provided" do
      let(:expires_in) { 60 }

      it "returns new fragment after expiration" do
        Timecop.travel(Time.now + 61)

        expect(execute_query.dig("data", "post")).to eq({
          "id" => "1",
          "title" => "new object test"
        })
      end
    end
  end

  context "when key part option is passed" do
    let(:resolver) do
      ->(id:, expires_in:) do
        cache_fragment(query_cache_key: "my_key") { Post.find(id) }
      end
    end

    it "returns the same cache fragment for a different query when query_cache_key is constant" do
      variables[:id] = 2

      expect(execute_query.dig("data", "post")).to eq({
        "id" => "1",
        "title" => "object test"
      })
    end
  end

  xcontext "when block and object are passed" do
    let(:resolver) do
      ->(id:, expires_in:) do
        cache_fragment(id, expires_in: expires_in) { Post.find(id) }
      end
    end

    # TODO: here will be test for passing object as a key
  end
end
