package com.example.logrep.destination.replication;

import java.util.List;
import java.util.Map;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * Expose les vues de supervision côté abonné, pratiques pour voir ce que fait la réplication.
 * JDBC simple : ce sont des catalogues/vues système, pas des entités métier.
 */
@RestController
public class ReplicationStatusController {

    private final JdbcTemplate jdbc;

    public ReplicationStatusController(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    @GetMapping("/replication/status")
    public Map<String, List<Map<String, Object>>> status() {
        return Map.of(
                // Une ligne par processus de la souscription (l'apply worker, plus un table-sync
                // worker pendant la copie initiale). received_lsn / latest_end_lsn avancent à
                // mesure que les changements arrivent ; last_msg_receipt_time montre que le lien
                // est vivant.
                "workers", jdbc.queryForList("""
                        SELECT subname, worker_type, pid, received_lsn::text, latest_end_lsn::text,
                               last_msg_send_time, last_msg_receipt_time
                        FROM pg_stat_subscription
                        """),
                // État de la synchronisation initiale par table :
                //   i = initialisation, d = copie des données en cours, f = copie terminée,
                //   s = synchronisée, r = prête (réplication normale).
                "tables", jdbc.queryForList("""
                        SELECT s.subname, sr.srrelid::regclass::text AS table_name,
                               sr.srsubstate AS state
                        FROM pg_subscription_rel sr
                        JOIN pg_subscription s ON s.oid = sr.srsubid
                        """),
                // Compteurs d'erreurs (PG15+) : apply_error_count augmente quand un changement
                // entrant ne peut pas être appliqué (par exemple une violation de contrainte), ce
                // qui bloque la réplication.
                "errors", jdbc.queryForList("""
                        SELECT subname, apply_error_count, sync_error_count, stats_reset
                        FROM pg_stat_subscription_stats
                        """));
    }
}
