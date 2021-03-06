class PostSerializer < BasicPostSerializer

  # To pass in additional information we might need
  attr_accessor :topic_slug,
                :topic_view,
                :parent_post,
                :add_raw,
                :single_post_link_counts,
                :draft_sequence,
                :post_actions

  attributes :post_number,
             :post_type,
             :updated_at,
             :reply_count,
             :reply_to_post_number,
             :quote_count,
             :avg_time,
             :incoming_link_count,
             :reads,
             :score,
             :yours,
             :topic_slug,
             :topic_id,
             :display_username,
             :primary_group_name,
             :version,
             :can_edit,
             :can_delete,
             :can_recover,
             :link_counts,
             :read,
             :user_title,
             :reply_to_user,
             :bookmarked,
             :raw,
             :actions_summary,
             :moderator?,
             :admin?,
             :staff?,
             :user_id,
             :draft_sequence,
             :hidden,
             :hidden_reason_id,
             :trust_level,
             :deleted_at,
             :deleted_by,
             :user_deleted,
             :edit_reason,
             :can_view_edit_history,
             :wiki


  def moderator?
    !!(object.user && object.user.moderator?)
  end

  def admin?
    !!(object.user && object.user.admin?)
  end

  def staff?
    !!(object.user && object.user.staff?)
  end

  def yours
    scope.user == object.user
  end

  def can_edit
    scope.can_edit?(object)
  end

  def can_delete
    scope.can_delete?(object)
  end

  def can_recover
    scope.can_recover_post?(object)
  end

  def display_username
    object.user.try(:name)
  end

  def primary_group_name
    return nil unless object.user && object.user.primary_group_id

    if @topic_view
      @topic_view.primary_group_names[object.user.primary_group_id]
    else
      object.user.primary_group.name if object.user.primary_group
    end
  end

  def link_counts
    return @single_post_link_counts if @single_post_link_counts.present?

    # TODO: This could be better, just porting the old one over
    @topic_view.link_counts[object.id].map do |link|
      result = {}
      result[:url] = link[:url]
      result[:internal] = link[:internal]
      result[:reflection] = link[:reflection]
      result[:title] = link[:title] if link[:title].present?
      result[:clicks] = link[:clicks] || 0
      result
    end
  end

  def read
    @topic_view.read?(object.post_number)
  end

  def score
    object.score || 0
  end

  def user_title
    object.user.try(:title)
  end

  def trust_level
    object.user.try(:trust_level)
  end

  def reply_to_user
    {
      username: object.reply_to_user.username,
      avatar_template: object.reply_to_user.avatar_template
    }
  end

  def bookmarked
    true
  end

  def deleted_by
    BasicUserSerializer.new(object.deleted_by, root: false).as_json
  end

  def include_deleted_by?
    scope.is_staff? && object.deleted_by.present?
  end

  # Summary of the actions taken on this post
  def actions_summary
    result = []
    PostActionType.types.each do |sym, id|
      next if [:bookmark].include?(sym)
      count_col = "#{sym}_count".to_sym

      count = object.send(count_col) if object.respond_to?(count_col)
      count ||= 0
      action_summary = {id: id,
                        count: count,
                        hidden: (sym == :vote),
                        can_act: scope.post_can_act?(object, sym, taken_actions: post_actions)}

      # The following only applies if you're logged in
      if action_summary[:can_act] && scope.current_user.present?
        action_summary[:can_clear_flags] = scope.is_staff? && PostActionType.flag_types.values.include?(id)
      end

      if post_actions.present? && post_actions.has_key?(id)
        action_summary[:acted] = true
        action_summary[:can_undo] = scope.can_delete?(post_actions[id])
      end

      # only show public data
      unless scope.is_staff? || PostActionType.public_types.values.include?(id)
        action_summary[:count] = action_summary[:acted] ? 1 : 0
      end

      result << action_summary
    end

    result
  end

  def include_draft_sequence?
    @draft_sequence.present?
  end

  def include_slug_title?
    @topic_slug.present?
  end

  def include_raw?
    @add_raw.present? && (!object.hidden || scope.user.try(:staff?) || yours)
  end

  def include_link_counts?
    return true if @single_post_link_counts.present?

    @topic_view.present? && @topic_view.link_counts.present? && @topic_view.link_counts[object.id].present?
  end

  def include_read?
    @topic_view.present?
  end

  def include_reply_to_user?
    object.quoteless? && object.reply_to_user
  end

  def include_bookmarked?
    post_actions.present? && post_actions.keys.include?(PostActionType.types[:bookmark])
  end

  def include_display_username?
    SiteSetting.enable_names?
  end

  def can_view_edit_history
    scope.can_view_post_revisions?(object)
  end

  private

  def post_actions
    @post_actions ||= (@topic_view.present? && @topic_view.all_post_actions.present?) ? @topic_view.all_post_actions[object.id] : nil
  end
end
