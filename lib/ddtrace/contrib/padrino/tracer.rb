require 'ddtrace/contrib/sinatra/tracer'

module Datadog
  module Contrib
    module Padrino
      module Tracer
        # rubocop:disable Metrics/AbcSize
        # rubocop:disable Metrics/MethodLength
        def self.registered(app)
          ::Datadog::Contrib::Sinatra::Tracer.registered(app)

          ::Padrino::Application.class_eval do

            # This is a new method specifically for Padrino.
            # I've been unable to re-use Sinatra's global filters
            # (app.before and app.after) so this is the alternative
            def dispatch!(*args, &block)
              before
              super
              after
            end

            # Copied directly from sinatra/tracer.rb
            def render(engine, data, *)
              cfg = settings.datadog_tracer

              output = ''
              if cfg.enabled?
                tracer = cfg[:tracer]
                tracer.trace('sinatra.render_template') do |span|
                  # If data is a string, it is a literal template and we don't
                  # want to record it.
                  span.set_tag('sinatra.template_name', data) if data.is_a? Symbol
                  output = super
                end
              else
                output = super
              end

              output
            end

            # copied and renamed from the `app.before` block in sinatra/tracer.rb
            def before
              cfg = settings.datadog_tracer
              return unless cfg.enabled?

              if instance_variable_defined? :@datadog_request_span
                if @datadog_request_span
                  Datadog::Tracer.log.error('request span active in :before hook')
                  @datadog_request_span.finish()
                  @datadog_request_span = nil
                end
              end

              tracer = cfg[:tracer]

              span = tracer.trace('sinatra.request',
                                  service: cfg.cfg[:default_service],
                                  span_type: Datadog::Ext::HTTP::TYPE)
              span.set_tag(Datadog::Ext::HTTP::URL, request.path)
              span.set_tag(Datadog::Ext::HTTP::METHOD, request.request_method)

              @datadog_request_span = span
            end

            # copied and renamed from the `app.after` block in sinatra/tracer.rb
            def after
              cfg = settings.datadog_tracer
              return unless cfg.enabled?

              span = @datadog_request_span
              begin
                unless span
                  Datadog::Tracer.log.error('missing request span in :after hook')
                  return
                end

                span.resource = "#{request.request_method} #{@datadog_route}"
                span.set_tag('sinatra.route.path', @datadog_route)
                span.set_tag(Datadog::Ext::HTTP::STATUS_CODE, response.status)

                if response.server_error?
                  span.status = 1

                  err = env['sinatra.error']
                  if err
                    span.set_tag(Datadog::Ext::Errors::TYPE, err.class)
                    span.set_tag(Datadog::Ext::Errors::MSG, err.message)
                  end
                end

                span.finish()
              ensure
                @datadog_request_span = nil
              end
            end
          end
        end
      end
    end
  end
end

# rubocop:disable Style/Documentation
class Padrino::Application
  register Datadog::Contrib::Padrino::Tracer
end
