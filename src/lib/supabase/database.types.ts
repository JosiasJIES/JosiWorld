export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

export type Database = {
  // Allows to automatically instantiate createClient with right options
  // instead of createClient<Database, { PostgrestVersion: 'XX' }>(URL, KEY)
  __InternalSupabase: {
    PostgrestVersion: "14.18"
  }
  public: {
    Tables: {
      achievements: {
        Row: {
          code: string
          description: string
          id: string
          tasks_required: number
          title: string
          xp_required: number
        }
        Insert: {
          code: string
          description: string
          id?: string
          tasks_required?: number
          title: string
          xp_required?: number
        }
        Update: {
          code?: string
          description?: string
          id?: string
          tasks_required?: number
          title?: string
          xp_required?: number
        }
        Relationships: []
      }
      app_settings: {
        Row: {
          family_id: string
          level_xp_step: number
          updated_at: string
        }
        Insert: {
          family_id: string
          level_xp_step?: number
          updated_at?: string
        }
        Update: {
          family_id?: string
          level_xp_step?: number
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "app_settings_family_id_fkey"
            columns: ["family_id"]
            isOneToOne: true
            referencedRelation: "families"
            referencedColumns: ["id"]
          },
        ]
      }
      child_achievements: {
        Row: {
          achievement_id: string
          child_id: string
          unlocked_at: string
        }
        Insert: {
          achievement_id: string
          child_id: string
          unlocked_at?: string
        }
        Update: {
          achievement_id?: string
          child_id?: string
          unlocked_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "child_achievements_achievement_id_fkey"
            columns: ["achievement_id"]
            isOneToOne: false
            referencedRelation: "achievements"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "child_achievements_child_id_fkey"
            columns: ["child_id"]
            isOneToOne: false
            referencedRelation: "child_balances"
            referencedColumns: ["child_id"]
          },
          {
            foreignKeyName: "child_achievements_child_id_fkey"
            columns: ["child_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      diary_entries: {
        Row: {
          answers: Json
          child_id: string
          created_at: string
          entry_date: string
          family_id: string
          id: string
          updated_at: string
        }
        Insert: {
          answers?: Json
          child_id: string
          created_at?: string
          entry_date: string
          family_id: string
          id?: string
          updated_at?: string
        }
        Update: {
          answers?: Json
          child_id?: string
          created_at?: string
          entry_date?: string
          family_id?: string
          id?: string
          updated_at?: string
        }
        Relationships: []
      }
      diary_prompts: {
        Row: {
          created_at: string
          family_id: string
          id: string
          position: number
          question: string
        }
        Insert: {
          created_at?: string
          family_id: string
          id?: string
          position?: number
          question: string
        }
        Update: {
          created_at?: string
          family_id?: string
          id?: string
          position?: number
          question?: string
        }
        Relationships: []
      }
      child_invites: {
        Row: {
          avatar: string
          birth_date: string | null
          created_at: string
          display_name: string
          family_id: string
          token: string
          username: string
        }
        Insert: {
          avatar?: string
          birth_date?: string | null
          created_at?: string
          display_name: string
          family_id: string
          token?: string
          username: string
        }
        Update: {
          avatar?: string
          birth_date?: string | null
          created_at?: string
          display_name?: string
          family_id?: string
          token?: string
          username?: string
        }
        Relationships: [
          {
            foreignKeyName: "child_invites_family_id_fkey"
            columns: ["family_id"]
            isOneToOne: false
            referencedRelation: "families"
            referencedColumns: ["id"]
          },
        ]
      }
      extra_task_claims: {
        Row: {
          amount_snapshot: number
          child_id: string
          claimed_at: string
          family_id: string
          id: string
          review_note: string | null
          reviewed_at: string | null
          reviewed_by: string | null
          status: Database["public"]["Enums"]["extra_claim_status"]
          submitted_at: string | null
          task_id: string
          title_snapshot: string
        }
        Insert: {
          amount_snapshot: number
          child_id: string
          claimed_at?: string
          family_id: string
          id?: string
          review_note?: string | null
          reviewed_at?: string | null
          reviewed_by?: string | null
          status?: Database["public"]["Enums"]["extra_claim_status"]
          submitted_at?: string | null
          task_id: string
          title_snapshot: string
        }
        Update: {
          amount_snapshot?: number
          child_id?: string
          claimed_at?: string
          family_id?: string
          id?: string
          review_note?: string | null
          reviewed_at?: string | null
          reviewed_by?: string | null
          status?: Database["public"]["Enums"]["extra_claim_status"]
          submitted_at?: string | null
          task_id?: string
          title_snapshot?: string
        }
        Relationships: [
          {
            foreignKeyName: "extra_task_claims_child_id_family_id_fkey"
            columns: ["child_id", "family_id"]
            isOneToOne: false
            referencedRelation: "child_balances"
            referencedColumns: ["child_id", "family_id"]
          },
          {
            foreignKeyName: "extra_task_claims_child_id_family_id_fkey"
            columns: ["child_id", "family_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id", "family_id"]
          },
          {
            foreignKeyName: "extra_task_claims_family_id_fkey"
            columns: ["family_id"]
            isOneToOne: false
            referencedRelation: "families"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "extra_task_claims_reviewed_by_fkey"
            columns: ["reviewed_by"]
            isOneToOne: false
            referencedRelation: "child_balances"
            referencedColumns: ["child_id"]
          },
          {
            foreignKeyName: "extra_task_claims_reviewed_by_fkey"
            columns: ["reviewed_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "extra_task_claims_task_id_family_id_fkey"
            columns: ["task_id", "family_id"]
            isOneToOne: false
            referencedRelation: "tasks"
            referencedColumns: ["id", "family_id"]
          },
        ]
      }
      families: {
        Row: {
          created_at: string
          currency_name: string
          currency_symbol: string
          id: string
          name: string
          owner_id: string
        }
        Insert: {
          created_at?: string
          currency_name?: string
          currency_symbol?: string
          id?: string
          name?: string
          owner_id: string
        }
        Update: {
          created_at?: string
          currency_name?: string
          currency_symbol?: string
          id?: string
          name?: string
          owner_id?: string
        }
        Relationships: []
      }
      ledger_entries: {
        Row: {
          account: string
          amount: number
          child_id: string
          created_at: string
          family_id: string
          goal_id: string | null
          id: number
          transaction_id: string
        }
        Insert: {
          account: string
          amount: number
          child_id: string
          created_at?: string
          family_id: string
          goal_id?: string | null
          id?: never
          transaction_id: string
        }
        Update: {
          account?: string
          amount?: number
          child_id?: string
          created_at?: string
          family_id?: string
          goal_id?: string | null
          id?: never
          transaction_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "ledger_entries_child_id_fkey"
            columns: ["child_id"]
            isOneToOne: false
            referencedRelation: "child_balances"
            referencedColumns: ["child_id"]
          },
          {
            foreignKeyName: "ledger_entries_child_id_fkey"
            columns: ["child_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "ledger_entries_family_id_fkey"
            columns: ["family_id"]
            isOneToOne: false
            referencedRelation: "families"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "ledger_entries_goal_id_fkey"
            columns: ["goal_id"]
            isOneToOne: false
            referencedRelation: "savings_goals"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "ledger_entries_transaction_id_fkey"
            columns: ["transaction_id"]
            isOneToOne: false
            referencedRelation: "ledger_transactions"
            referencedColumns: ["id"]
          },
        ]
      }
      ledger_transactions: {
        Row: {
          amount: number
          child_id: string
          created_at: string
          created_by: string | null
          description: string
          family_id: string
          id: string
          kind: Database["public"]["Enums"]["ledger_kind"]
          source_id: string | null
        }
        Insert: {
          amount: number
          child_id: string
          created_at?: string
          created_by?: string | null
          description: string
          family_id: string
          id?: string
          kind: Database["public"]["Enums"]["ledger_kind"]
          source_id?: string | null
        }
        Update: {
          amount?: number
          child_id?: string
          created_at?: string
          created_by?: string | null
          description?: string
          family_id?: string
          id?: string
          kind?: Database["public"]["Enums"]["ledger_kind"]
          source_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "ledger_transactions_child_id_fkey"
            columns: ["child_id"]
            isOneToOne: false
            referencedRelation: "child_balances"
            referencedColumns: ["child_id"]
          },
          {
            foreignKeyName: "ledger_transactions_child_id_fkey"
            columns: ["child_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "ledger_transactions_created_by_fkey"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "child_balances"
            referencedColumns: ["child_id"]
          },
          {
            foreignKeyName: "ledger_transactions_created_by_fkey"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "ledger_transactions_family_id_fkey"
            columns: ["family_id"]
            isOneToOne: false
            referencedRelation: "families"
            referencedColumns: ["id"]
          },
        ]
      }
      profiles: {
        Row: {
          avatar: string
          birth_date: string | null
          created_at: string
          display_name: string
          family_id: string
          id: string
          is_active: boolean
          role: Database["public"]["Enums"]["app_role"]
          username: string | null
          xp: number
        }
        Insert: {
          avatar?: string
          birth_date?: string | null
          created_at?: string
          display_name: string
          family_id: string
          id: string
          is_active?: boolean
          role: Database["public"]["Enums"]["app_role"]
          username?: string | null
          xp?: number
        }
        Update: {
          avatar?: string
          birth_date?: string | null
          created_at?: string
          display_name?: string
          family_id?: string
          id?: string
          is_active?: boolean
          role?: Database["public"]["Enums"]["app_role"]
          username?: string | null
          xp?: number
        }
        Relationships: [
          {
            foreignKeyName: "profiles_family_id_fkey"
            columns: ["family_id"]
            isOneToOne: false
            referencedRelation: "families"
            referencedColumns: ["id"]
          },
        ]
      }
      reward_redemptions: {
        Row: {
          child_id: string
          family_id: string
          id: string
          price_snapshot: number
          requested_at: string
          review_note: string | null
          reviewed_at: string | null
          reviewed_by: string | null
          reward_id: string
          status: Database["public"]["Enums"]["request_status"]
        }
        Insert: {
          child_id: string
          family_id: string
          id?: string
          price_snapshot: number
          requested_at?: string
          review_note?: string | null
          reviewed_at?: string | null
          reviewed_by?: string | null
          reward_id: string
          status?: Database["public"]["Enums"]["request_status"]
        }
        Update: {
          child_id?: string
          family_id?: string
          id?: string
          price_snapshot?: number
          requested_at?: string
          review_note?: string | null
          reviewed_at?: string | null
          reviewed_by?: string | null
          reward_id?: string
          status?: Database["public"]["Enums"]["request_status"]
        }
        Relationships: [
          {
            foreignKeyName: "reward_redemptions_child_id_fkey"
            columns: ["child_id"]
            isOneToOne: false
            referencedRelation: "child_balances"
            referencedColumns: ["child_id"]
          },
          {
            foreignKeyName: "reward_redemptions_child_id_fkey"
            columns: ["child_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "reward_redemptions_family_id_fkey"
            columns: ["family_id"]
            isOneToOne: false
            referencedRelation: "families"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "reward_redemptions_reviewed_by_fkey"
            columns: ["reviewed_by"]
            isOneToOne: false
            referencedRelation: "child_balances"
            referencedColumns: ["child_id"]
          },
          {
            foreignKeyName: "reward_redemptions_reviewed_by_fkey"
            columns: ["reviewed_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "reward_redemptions_reward_id_fkey"
            columns: ["reward_id"]
            isOneToOne: false
            referencedRelation: "rewards"
            referencedColumns: ["id"]
          },
        ]
      }
      rewards: {
        Row: {
          active: boolean
          assigned_child_id: string | null
          category: string
          created_at: string
          description: string
          family_id: string
          id: string
          price: number
          title: string
        }
        Insert: {
          active?: boolean
          assigned_child_id?: string | null
          category?: string
          created_at?: string
          description?: string
          family_id: string
          id?: string
          price: number
          title: string
        }
        Update: {
          active?: boolean
          assigned_child_id?: string | null
          category?: string
          created_at?: string
          description?: string
          family_id?: string
          id?: string
          price?: number
          title?: string
        }
        Relationships: [
          {
            foreignKeyName: "rewards_assigned_child_id_fkey"
            columns: ["assigned_child_id"]
            isOneToOne: false
            referencedRelation: "child_balances"
            referencedColumns: ["child_id"]
          },
          {
            foreignKeyName: "rewards_assigned_child_id_fkey"
            columns: ["assigned_child_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "rewards_family_id_fkey"
            columns: ["family_id"]
            isOneToOne: false
            referencedRelation: "families"
            referencedColumns: ["id"]
          },
        ]
      }
      routine_activities: {
        Row: {
          active: boolean
          amount: number
          created_at: string
          description: string
          family_id: string
          id: string
          position: number
          routine_id: string
          title: string
        }
        Insert: {
          active?: boolean
          amount: number
          created_at?: string
          description?: string
          family_id: string
          id?: string
          position?: number
          routine_id: string
          title: string
        }
        Update: {
          active?: boolean
          amount?: number
          created_at?: string
          description?: string
          family_id?: string
          id?: string
          position?: number
          routine_id?: string
          title?: string
        }
        Relationships: [
          {
            foreignKeyName: "routine_activities_family_id_fkey"
            columns: ["family_id"]
            isOneToOne: false
            referencedRelation: "families"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "routine_activities_routine_id_family_id_fkey"
            columns: ["routine_id", "family_id"]
            isOneToOne: false
            referencedRelation: "routines"
            referencedColumns: ["id", "family_id"]
          },
        ]
      }
      routine_submission_items: {
        Row: {
          activity_id: string
          amount_snapshot: number
          created_at: string
          family_id: string
          id: string
          review_note: string | null
          reviewed_at: string | null
          reviewed_by: string | null
          routine_id: string
          status: Database["public"]["Enums"]["request_status"]
          submission_id: string
          title_snapshot: string
        }
        Insert: {
          activity_id: string
          amount_snapshot: number
          created_at?: string
          family_id: string
          id?: string
          review_note?: string | null
          reviewed_at?: string | null
          reviewed_by?: string | null
          routine_id: string
          status?: Database["public"]["Enums"]["request_status"]
          submission_id: string
          title_snapshot: string
        }
        Update: {
          activity_id?: string
          amount_snapshot?: number
          created_at?: string
          family_id?: string
          id?: string
          review_note?: string | null
          reviewed_at?: string | null
          reviewed_by?: string | null
          routine_id?: string
          status?: Database["public"]["Enums"]["request_status"]
          submission_id?: string
          title_snapshot?: string
        }
        Relationships: [
          {
            foreignKeyName: "routine_submission_items_activity_id_routine_id_fkey"
            columns: ["activity_id", "routine_id"]
            isOneToOne: false
            referencedRelation: "routine_activities"
            referencedColumns: ["id", "routine_id"]
          },
          {
            foreignKeyName: "routine_submission_items_reviewed_by_fkey"
            columns: ["reviewed_by"]
            isOneToOne: false
            referencedRelation: "child_balances"
            referencedColumns: ["child_id"]
          },
          {
            foreignKeyName: "routine_submission_items_reviewed_by_fkey"
            columns: ["reviewed_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "routine_submission_items_submission_id_routine_id_family_i_fkey"
            columns: ["submission_id", "routine_id", "family_id"]
            isOneToOne: false
            referencedRelation: "routine_submissions"
            referencedColumns: ["id", "routine_id", "family_id"]
          },
        ]
      }
      routine_submissions: {
        Row: {
          child_id: string
          deadline_time_snapshot: string
          family_id: string
          id: string
          payout_mode: string
          review_note: string | null
          reviewed_at: string | null
          reviewed_by: string | null
          routine_id: string
          scheduled_date: string
          status: Database["public"]["Enums"]["request_status"]
          submitted_at: string
          total_amount: number
        }
        Insert: {
          child_id: string
          deadline_time_snapshot?: string
          family_id: string
          id?: string
          payout_mode: string
          review_note?: string | null
          reviewed_at?: string | null
          reviewed_by?: string | null
          routine_id: string
          scheduled_date: string
          status?: Database["public"]["Enums"]["request_status"]
          submitted_at?: string
          total_amount: number
        }
        Update: {
          child_id?: string
          deadline_time_snapshot?: string
          family_id?: string
          id?: string
          payout_mode?: string
          review_note?: string | null
          reviewed_at?: string | null
          reviewed_by?: string | null
          routine_id?: string
          scheduled_date?: string
          status?: Database["public"]["Enums"]["request_status"]
          submitted_at?: string
          total_amount?: number
        }
        Relationships: [
          {
            foreignKeyName: "routine_submissions_child_id_family_id_fkey"
            columns: ["child_id", "family_id"]
            isOneToOne: false
            referencedRelation: "child_balances"
            referencedColumns: ["child_id", "family_id"]
          },
          {
            foreignKeyName: "routine_submissions_child_id_family_id_fkey"
            columns: ["child_id", "family_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id", "family_id"]
          },
          {
            foreignKeyName: "routine_submissions_family_id_fkey"
            columns: ["family_id"]
            isOneToOne: false
            referencedRelation: "families"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "routine_submissions_reviewed_by_fkey"
            columns: ["reviewed_by"]
            isOneToOne: false
            referencedRelation: "child_balances"
            referencedColumns: ["child_id"]
          },
          {
            foreignKeyName: "routine_submissions_reviewed_by_fkey"
            columns: ["reviewed_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "routine_submissions_routine_id_family_id_fkey"
            columns: ["routine_id", "family_id"]
            isOneToOne: false
            referencedRelation: "routines"
            referencedColumns: ["id", "family_id"]
          },
        ]
      }
      routine_streaks: {
        Row: {
          best_streak: number
          child_id: string
          current_streak: number
          family_id: string
          last_completed_date: string | null
          routine_id: string
          updated_at: string
        }
        Insert: {
          best_streak?: number
          child_id: string
          current_streak?: number
          family_id: string
          last_completed_date?: string | null
          routine_id: string
          updated_at?: string
        }
        Update: {
          best_streak?: number
          child_id?: string
          current_streak?: number
          family_id?: string
          last_completed_date?: string | null
          routine_id?: string
          updated_at?: string
        }
        Relationships: []
      }
      routine_streak_medals: {
        Row: {
          awarded_at: string
          child_id: string
          family_id: string
          id: string
          milestone: number
          routine_id: string
        }
        Insert: {
          awarded_at?: string
          child_id: string
          family_id: string
          id?: string
          milestone: number
          routine_id: string
        }
        Update: {
          awarded_at?: string
          child_id?: string
          family_id?: string
          id?: string
          milestone?: number
          routine_id?: string
        }
        Relationships: []
      }
      routines: {
        Row: {
          active: boolean
          assigned_child_id: string | null
          created_at: string
          deadline_time: string
          description: string
          family_id: string
          id: string
          payout_mode: string
          title: string
          weekdays: number[]
        }
        Insert: {
          active?: boolean
          assigned_child_id?: string | null
          created_at?: string
          deadline_time?: string
          description?: string
          family_id: string
          id?: string
          payout_mode: string
          title: string
          weekdays?: number[]
        }
        Update: {
          active?: boolean
          assigned_child_id?: string | null
          created_at?: string
          deadline_time?: string
          description?: string
          family_id?: string
          id?: string
          payout_mode?: string
          title?: string
          weekdays?: number[]
        }
        Relationships: [
          {
            foreignKeyName: "routines_assigned_child_id_family_id_fkey"
            columns: ["assigned_child_id", "family_id"]
            isOneToOne: false
            referencedRelation: "child_balances"
            referencedColumns: ["child_id", "family_id"]
          },
          {
            foreignKeyName: "routines_assigned_child_id_family_id_fkey"
            columns: ["assigned_child_id", "family_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id", "family_id"]
          },
          {
            foreignKeyName: "routines_family_id_fkey"
            columns: ["family_id"]
            isOneToOne: false
            referencedRelation: "families"
            referencedColumns: ["id"]
          },
        ]
      }
      savings_goals: {
        Row: {
          active: boolean
          child_id: string
          created_at: string
          family_id: string
          id: string
          target_amount: number
          title: string
        }
        Insert: {
          active?: boolean
          child_id: string
          created_at?: string
          family_id: string
          id?: string
          target_amount: number
          title: string
        }
        Update: {
          active?: boolean
          child_id?: string
          created_at?: string
          family_id?: string
          id?: string
          target_amount?: number
          title?: string
        }
        Relationships: [
          {
            foreignKeyName: "savings_goals_child_id_fkey"
            columns: ["child_id"]
            isOneToOne: false
            referencedRelation: "child_balances"
            referencedColumns: ["child_id"]
          },
          {
            foreignKeyName: "savings_goals_child_id_fkey"
            columns: ["child_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "savings_goals_family_id_fkey"
            columns: ["family_id"]
            isOneToOne: false
            referencedRelation: "families"
            referencedColumns: ["id"]
          },
        ]
      }
      task_submissions: {
        Row: {
          amount_snapshot: number
          child_id: string
          family_id: string
          id: string
          note: string
          review_note: string | null
          reviewed_at: string | null
          reviewed_by: string | null
          status: Database["public"]["Enums"]["request_status"]
          submitted_at: string
          task_id: string
        }
        Insert: {
          amount_snapshot: number
          child_id: string
          family_id: string
          id?: string
          note?: string
          review_note?: string | null
          reviewed_at?: string | null
          reviewed_by?: string | null
          status?: Database["public"]["Enums"]["request_status"]
          submitted_at?: string
          task_id: string
        }
        Update: {
          amount_snapshot?: number
          child_id?: string
          family_id?: string
          id?: string
          note?: string
          review_note?: string | null
          reviewed_at?: string | null
          reviewed_by?: string | null
          status?: Database["public"]["Enums"]["request_status"]
          submitted_at?: string
          task_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "task_submissions_child_id_fkey"
            columns: ["child_id"]
            isOneToOne: false
            referencedRelation: "child_balances"
            referencedColumns: ["child_id"]
          },
          {
            foreignKeyName: "task_submissions_child_id_fkey"
            columns: ["child_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "task_submissions_family_id_fkey"
            columns: ["family_id"]
            isOneToOne: false
            referencedRelation: "families"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "task_submissions_reviewed_by_fkey"
            columns: ["reviewed_by"]
            isOneToOne: false
            referencedRelation: "child_balances"
            referencedColumns: ["child_id"]
          },
          {
            foreignKeyName: "task_submissions_reviewed_by_fkey"
            columns: ["reviewed_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "task_submissions_task_id_fkey"
            columns: ["task_id"]
            isOneToOne: false
            referencedRelation: "tasks"
            referencedColumns: ["id"]
          },
        ]
      }
      tasks: {
        Row: {
          active: boolean
          amount: number
          assigned_child_id: string | null
          category: string
          created_at: string
          description: string
          due_at: string | null
          family_id: string
          frequency: string
          id: string
          title: string
        }
        Insert: {
          active?: boolean
          amount: number
          assigned_child_id?: string | null
          category?: string
          created_at?: string
          description?: string
          due_at?: string | null
          family_id: string
          frequency?: string
          id?: string
          title: string
        }
        Update: {
          active?: boolean
          amount?: number
          assigned_child_id?: string | null
          category?: string
          created_at?: string
          description?: string
          due_at?: string | null
          family_id?: string
          frequency?: string
          id?: string
          title?: string
        }
        Relationships: [
          {
            foreignKeyName: "tasks_assigned_child_id_fkey"
            columns: ["assigned_child_id"]
            isOneToOne: false
            referencedRelation: "child_balances"
            referencedColumns: ["child_id"]
          },
          {
            foreignKeyName: "tasks_assigned_child_id_fkey"
            columns: ["assigned_child_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "tasks_family_id_fkey"
            columns: ["family_id"]
            isOneToOne: false
            referencedRelation: "families"
            referencedColumns: ["id"]
          },
        ]
      }
    }
    Views: {
      child_balances: {
        Row: {
          available_balance: number | null
          child_id: string | null
          family_id: string | null
          savings_balance: number | null
        }
        Relationships: [
          {
            foreignKeyName: "profiles_family_id_fkey"
            columns: ["family_id"]
            isOneToOne: false
            referencedRelation: "families"
            referencedColumns: ["id"]
          },
        ]
      }
    }
    Functions: {
      claim_extra_task: { Args: { task_uuid: string }; Returns: string }
      is_family_child: { Args: { target_family: string }; Returns: boolean }
      is_family_parent: { Args: { target_family: string }; Returns: boolean }
      is_self_child: { Args: { target_id: string }; Returns: boolean }
      update_my_avatar: { Args: { avatar_path: string | null }; Returns: undefined }
      move_savings:
        | {
            Args: {
              amount_to_move: number
              deposit: boolean
              goal_uuid: string
            }
            Returns: undefined
          }
        | {
            Args: {
              amount_to_move: number
              deposit: boolean
              goal_uuid: string
              idempotency_key: string
            }
            Returns: undefined
          }
      parent_adjustment: {
        Args: {
          amount_to_adjust: number
          direction: string
          idempotency_key: string
          reason: string
          target_child: string
        }
        Returns: undefined
      }
      release_extra_task_claim: {
        Args: { claim_uuid: string }
        Returns: undefined
      }
      request_redemption: { Args: { reward_uuid: string }; Returns: string }
      request_task: {
        Args: { submission_note?: string; task_uuid: string }
        Returns: string
      }
      review_extra_task_claim: {
        Args: { approve: boolean; claim_uuid: string; decision_note?: string }
        Returns: undefined
      }
      review_redemption: {
        Args: {
          approve: boolean
          decision_note?: string
          redemption_uuid: string
        }
        Returns: undefined
      }
      review_routine_activity_item: {
        Args: { approve: boolean; decision_note?: string; item_uuid: string }
        Returns: undefined
      }
      review_routine_completion: {
        Args: {
          approve: boolean
          decision_note?: string
          submission_uuid: string
        }
        Returns: undefined
      }
      review_task: {
        Args: {
          approve: boolean
          decision_note?: string
          submission_uuid: string
        }
        Returns: undefined
      }
      save_routine: {
        Args: {
          activities: Json
          child_uuid: string | null
          deadline_at: string
          routine_description: string
          routine_payout_mode: string
          routine_title: string
          routine_uuid: string | null
          routine_weekdays: number[]
        }
        Returns: string
      }
      set_routine_active: {
        Args: { make_active: boolean; routine_uuid: string }
        Returns: undefined
      }
      submit_extra_task_claim: {
        Args: { claim_uuid: string }
        Returns: undefined
      }
      submit_routine: {
        Args: { activity_uuids: string[]; routine_uuid: string }
        Returns: string
      }
      unlock_achievements: {
        Args: { target_child: string }
        Returns: undefined
      }
    }
    Enums: {
      app_role: "PARENT" | "CHILD"
      extra_claim_status:
        | "CLAIMED"
        | "PENDING"
        | "APPROVED"
        | "REJECTED"
        | "RELEASED"
      ledger_kind:
        | "TASK_REWARD"
        | "REWARD_REDEMPTION"
        | "SAVINGS_DEPOSIT"
        | "SAVINGS_WITHDRAWAL"
        | "ADJUSTMENT"
      request_status: "PENDING" | "APPROVED" | "REJECTED"
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
}

type DatabaseWithoutInternals = Omit<Database, "__InternalSupabase">

type DefaultSchema = DatabaseWithoutInternals[Extract<keyof Database, "public">]

export type Tables<
  DefaultSchemaTableNameOrOptions extends
    | keyof (DefaultSchema["Tables"] & DefaultSchema["Views"])
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
        DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
      DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])[TableName] extends {
      Row: infer R
    }
    ? R
    : never
  : DefaultSchemaTableNameOrOptions extends keyof (DefaultSchema["Tables"] &
        DefaultSchema["Views"])
    ? (DefaultSchema["Tables"] &
        DefaultSchema["Views"])[DefaultSchemaTableNameOrOptions] extends {
        Row: infer R
      }
      ? R
      : never
    : never

export type TablesInsert<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Insert: infer I
    }
    ? I
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Insert: infer I
      }
      ? I
      : never
    : never

export type TablesUpdate<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Update: infer U
    }
    ? U
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Update: infer U
      }
      ? U
      : never
    : never

export type Enums<
  DefaultSchemaEnumNameOrOptions extends
    | keyof DefaultSchema["Enums"]
    | { schema: keyof DatabaseWithoutInternals },
  EnumName extends (DefaultSchemaEnumNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"]
    : never) = never,
> = DefaultSchemaEnumNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"][EnumName]
  : DefaultSchemaEnumNameOrOptions extends keyof DefaultSchema["Enums"]
    ? DefaultSchema["Enums"][DefaultSchemaEnumNameOrOptions]
    : never

export type CompositeTypes<
  PublicCompositeTypeNameOrOptions extends
    | keyof DefaultSchema["CompositeTypes"]
    | { schema: keyof DatabaseWithoutInternals },
  CompositeTypeName extends (PublicCompositeTypeNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"]
    : never) = never,
> = PublicCompositeTypeNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"][CompositeTypeName]
  : PublicCompositeTypeNameOrOptions extends keyof DefaultSchema["CompositeTypes"]
    ? DefaultSchema["CompositeTypes"][PublicCompositeTypeNameOrOptions]
    : never

export const Constants = {
  public: {
    Enums: {
      app_role: ["PARENT", "CHILD"],
      extra_claim_status: [
        "CLAIMED",
        "PENDING",
        "APPROVED",
        "REJECTED",
        "RELEASED",
      ],
      ledger_kind: [
        "TASK_REWARD",
        "REWARD_REDEMPTION",
        "SAVINGS_DEPOSIT",
        "SAVINGS_WITHDRAWAL",
        "ADJUSTMENT",
      ],
      request_status: ["PENDING", "APPROVED", "REJECTED"],
    },
  },
} as const
