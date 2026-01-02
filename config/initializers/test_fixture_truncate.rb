if Rails.env.test?
  module FixtureTruncatePostgres
    def insert_fixtures_set(fixture_set, tables_to_delete = [])
      table_order = %w[
        users
        roles
        permissions
        role_permissions
        school_classes
        enrollments
        class_sessions
        class_session_overrides
        attendance_policies
        qr_sessions
        qr_scan_events
        attendance_records
        attendance_requests
        attendance_changes
        notifications
        push_subscriptions
        operation_requests
        audit_saved_searches
        api_keys
        devices
        sso_providers
        sso_identities
      ]
      ordered_fixture_set = fixture_set.sort_by do |table_name, _|
        table_order.index(table_name.to_s) || table_order.length
      end.to_h
      fixture_inserts = build_fixture_statements(ordered_fixture_set)
      statements = []

      if tables_to_delete.present?
        table_names = tables_to_delete.map { |table| quote_table_name(table) }.join(", ")
        statements << "TRUNCATE #{table_names} CASCADE"
      end

      statements.concat(fixture_inserts)

      transaction(requires_new: true) do
        execute_batch(statements, "Fixtures Load")
      end
    end
  end

  ActiveSupport.on_load(:active_record) do
    if defined?(ActiveRecord::ConnectionAdapters::PostgreSQLAdapter)
      ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.prepend(FixtureTruncatePostgres)
    end
  end
end
