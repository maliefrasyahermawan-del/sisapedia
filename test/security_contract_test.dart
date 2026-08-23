import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sisapedia/data/models/submission_model.dart';

bool _balancedSqlParentheses(String sql) {
  var depth = 0;
  var quoted = false;
  for (var i = 0; i < sql.length; i++) {
    final character = sql[i];
    if (character == "'") {
      if (quoted && i + 1 < sql.length && sql[i + 1] == "'") {
        i++;
      } else {
        quoted = !quoted;
      }
      continue;
    }
    if (quoted) continue;
    if (character == '(') depth++;
    if (character == ')') {
      depth--;
      if (depth < 0) return false;
    }
  }
  return !quoted && depth == 0;
}

void main() {
  test('submission DTO carries privacy-safe location contract', () {
    const submission = SubmissionModel(
      id: 's1',
      uid: 'u1',
      kategori: WasteCategory.organik,
      subtipe: 'Sisa sayur',
      beratKg: 2,
      district: 'Banyumanik',
      address: 'Pasar Sampangan',
      latitude: -7.02,
      longitude: 110.4,
    );
    final map = submission.toMap();
    expect(map['district'], 'Banyumanik');
    expect(map['latitude'], -7.02);
    expect(map.containsKey('precise_latitude'), isFalse);
  });

  test('migration contracts keep privileged and lifecycle writes narrow', () {
    final sql = File(
      'supabase/migrations/202608230002_security_workflow.sql',
    ).readAsStringSync();
    expect(
      sql,
      contains(
        "requested:=lower(coalesce(new.raw_user_meta_data->>'primary_role'",
      ),
    );
    expect(sql, contains("safe_role:=case when requested='pengolah'"));
    expect(sql, contains('primary_role_is_immutable'));
    expect(sql, contains('status<>\'en_route\''));
    expect(sql, contains('provision_privileged_profile'));
    expect(
      sql,
      contains('grant execute on function public.dlh_city_metrics()'),
    );
    expect(sql, contains('fulfill_redeem'));
    expect(sql, contains("candidate_rank<=3"));
  });

  test(
    '005 locks operational availability, trusted bootstrap, and content drafts',
    () {
      final sql = File(
        'supabase/migrations/202608230005_role_content_matching.sql',
      ).readAsStringSync();
      expect(sql, contains('add column if not exists active boolean'));
      expect(
        sql,
        contains('add column if not exists pickup_available boolean'),
      );
      expect(sql, contains('pp.active and pp.pickup_available'));
      expect(sql, contains('pickup_start_time'));
      expect(sql, contains("current_user not in ('postgres','service_role')"));
      expect(
        sql,
        contains(
          'grant execute on function public.provision_privileged_profile',
        ),
      );
      expect(
        sql,
        contains('create or replace function public.create_content_draft'),
      );
      expect(
        sql,
        contains("revoke insert,update on public.content from authenticated"),
      );
      expect(
        sql,
        contains("revoke insert,update on public.events from authenticated"),
      );
      expect(
        sql,
        contains('create or replace function public.update_content_draft'),
      );
      expect(
        sql,
        contains('grant execute on function public.update_content_draft'),
      );
      expect(sql, contains('content_submit'));
      expect(sql, contains('Hasil moderasi konten'));
    },
  );

  test(
    'normal snapshots keep evidence private and reveal selected locations only after acceptance',
    () {
      final provider = File(
        'lib/core/providers/role_snapshot_provider.dart',
      ).readAsStringSync();
      expect(provider, contains("from('weighing-evidence')"));
      expect(provider, contains('createSignedUrl'));
      expect(provider, contains("from('submission_locations')"));
      expect(provider, contains("'accepted'"));
      expect(provider, contains("'disputed'"));
      expect(provider, contains('precise_address'));
    },
  );

  test(
    '006 hardens processor writes, privacy, bootstrap, and exact matching',
    () {
      final sql = File(
        'supabase/migrations/202608230006_batch_a_hardening.sql',
      ).readAsStringSync();
      expect(sql, contains('processor_materials'));
      expect(
        sql,
        contains('revoke insert,update,delete on public.processor_profiles'),
      );
      expect(sql, contains('update_processor_operational'));
      expect(sql, contains("session_user in ('postgres','service_role')"));
      expect(sql, contains("coalesce(auth.jwt()->>'role','')='service_role'"));
      expect(sql, contains('p_precise_address'));
      expect(sql, contains('processor_pickup_window_matches'));
      expect(sql, contains('pm.material_subtype'));
      expect(sql, isNot(contains('then .7')));
    },
  );

  test('007 closes evidence, formula provenance, Sari limits, and offers', () {
    final sql = File(
      'supabase/migrations/202608230007_batch_b_workflow.sql',
    ).readAsStringSync();
    expect(sql, contains('consume_sari_rate_limit'));
    expect(sql, contains('offers_one_pending_submission'));
    expect(sql, contains('formula_id'));
    expect(sql, contains('economic_factor'));
    expect(sql, contains("o.bucket_id='weighing-evidence'"));
    expect(sql, contains('evidence_object_not_found'));
    expect(
      sql,
      contains("coalesce(t.resolved_at,t.completed_at,s.resolved_at)"),
    );
    expect(
      sql,
      contains('p_reason text,p_corrected_weight_kg numeric default null'),
    );
    expect(
      sql,
      contains("grant execute on function public.provision_privileged_profile"),
    );
    expect(sql, isNot(contains('s.completed_at')));
    expect(
      sql,
      contains(
        "s.status='accepted' and nullif(trim(coalesce(p_reason,'')),'') is null",
      ),
    );
    final lintFixes = File(
      'supabase/migrations/202608230008_runtime_lint_fixes.sql',
    ).readAsStringSync();
    expect(
      lintFixes,
      contains(
        'on conflict(redeem_request_id) where redeem_request_id is not null do nothing',
      ),
    );
    expect(
      lintFixes,
      contains(
        'drop function if exists public.resolve_dispute(uuid,boolean,text)',
      ),
    );
    expect(
      lintFixes,
      contains(
        "status=(case when p_approve then 'completed' else 'cancelled' end)::public.submission_status",
      ),
    );
    for (final path in [
      'supabase/migrations/202608230002_security_workflow.sql',
      'supabase/migrations/202608230007_batch_b_workflow.sql',
      'supabase/migrations/202608230009_batch_c_contracts.sql',
    ]) {
      final statements = RegExp(
        r'create\s+policy[\s\S]*?;',
        caseSensitive: false,
      ).allMatches(File(path).readAsStringSync());
      for (final statement in statements) {
        final text = statement.group(0)!;
        if (text.toLowerCase().contains('on storage.objects')) {
          expect(_balancedSqlParentheses(text), isTrue, reason: '$path: $text');
        }
      }
    }
  });

  test(
    '009 exposes candidate and aggregate provenance without widening writes',
    () {
      final sql = File(
        'supabase/migrations/202608230009_batch_c_contracts.sql',
      ).readAsStringSync();
      expect(sql, contains('grant select on table public.cities'));
      expect(sql, contains('create or replace function public.join_event'));
      expect(
        sql,
        contains(
          'revoke insert, update, delete on table public.event_participation',
        ),
      );
      expect(sql, contains('approximate_distance_km'));
      expect(sql, contains('provenance_components'));
      expect(sql, contains("date_trunc('month',now())"));
      expect(
        sql,
        contains("pp.status='approved' and pp.active and pp.pickup_available"),
      );
      expect(
        sql,
        contains(
          "grant execute on function public.join_event(uuid) to authenticated",
        ),
      );
      final finalAcceptance = File(
        'supabase/migrations/202608230010_final_acceptance.sql',
      ).readAsStringSync();
      expect(
        finalAcceptance,
        contains('revoke truncate, references, trigger on all tables'),
      );
      expect(
        finalAcceptance,
        contains('returns table(bucket_id text, object_path text)'),
      );
      expect(finalAcceptance, isNot(contains('delete from storage.objects')));
      expect(finalAcceptance, contains('p_completion_month date)'));
      expect(finalAcceptance, contains('p_event_at timestamptz'));
      final batchD = File(
        'supabase/migrations/202608230011_batch_d_acceptance.sql',
      ).readAsStringSync();
      expect(batchD, contains('retention_object_queue'));
      expect(batchD, contains('retention_acknowledge'));
      expect(
        batchD,
        contains(
          'drop function if exists public.create_content_draft(text,text,text)',
        ),
      );
      expect(batchD, contains('p_event_at timestamptz,p_event_location text'));
      expect(batchD, contains('set local role supabase_storage_admin'));
      for (final font in [
        'assets/fonts/RedHatDisplay[wght].ttf',
        'assets/fonts/RedHatText[wght].ttf',
      ]) {
        expect(File(font).readAsBytesSync().take(4), [0, 1, 0, 0]);
      }
      expect(
        File('assets/fonts/OFL-RedHat.txt').readAsStringSync(),
        contains('SIL Open Font License'),
      );
    },
  );

  test(
    'Sari edge contract authenticates Sumber and times out upstream calls',
    () {
      final edge = File(
        'supabase/functions/sari-proxy/index.ts',
      ).readAsStringSync();
      expect(edge, contains("profile?.primary_role !== 'sumber'"));
      expect(edge, contains('consume_sari_rate_limit'));
      expect(edge, contains('AbortController'));
      expect(edge, contains("operation === 'extract'"));
    },
  );
}
