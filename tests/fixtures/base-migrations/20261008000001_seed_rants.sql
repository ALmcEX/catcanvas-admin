begin;
-- Six actual Codex-authored examples from the approved design; no invented engagement.
insert into public.ai_generations(id,prompt,system_prompt,title,body,language,provider) values('60000000-0000-4000-8000-000000000001','做成吐槽平台 并自拟一些文案先添加上去
只有用户登录后才有上传吐槽，点赞/踩的权限
吐槽上传界面可以选择添加文字或者文字和照片一起（吐槽格式：标题 地点（位置） 正文 和照片）
并且可以对别人已上传的内容进行评价（用户可以在主页通过点击吐槽进入这条吐槽的页面，包含吐槽本身（图片和文字），以及评论区） 整体的主页面不显示评论，仅显示吐槽的标题以及地点）','Codex conversation drafts; no separate generation API system prompt was supplied.','The laundry timer is writing fiction','“One minute remaining” has lasted long enough for me to reconsider my major. I came here to wash a hoodie, not experience a new theory of time.','en','codex') on conflict(id) do nothing;
insert into public.rants(id,title,location,body,generation_id,is_example) values('70000000-0000-4000-8000-000000000001','The laundry timer is writing fiction','Columbia dorm laundry room','“One minute remaining” has lasted long enough for me to reconsider my major. I came here to wash a hoodie, not experience a new theory of time.','60000000-0000-4000-8000-000000000001',true) on conflict(id) do nothing;
insert into public.ai_generations(id,prompt,system_prompt,title,body,language,provider) values('60000000-0000-4000-8000-000000000002','做成吐槽平台 并自拟一些文案先添加上去
只有用户登录后才有上传吐槽，点赞/踩的权限
吐槽上传界面可以选择添加文字或者文字和照片一起（吐槽格式：标题 地点（位置） 正文 和照片）
并且可以对别人已上传的内容进行评价（用户可以在主页通过点击吐槽进入这条吐槽的页面，包含吐槽本身（图片和文字），以及评论区） 整体的主页面不显示评论，仅显示吐槽的标题以及地点）','Codex conversation drafts; no separate generation API system prompt was supplied.','The subway has entered its mystery era','The board says the train is arriving. The tunnel says absolutely nothing. At this point, I am in a long-distance relationship with the 1 train.','en','codex') on conflict(id) do nothing;
insert into public.rants(id,title,location,body,generation_id,is_example) values('70000000-0000-4000-8000-000000000002','The subway has entered its mystery era','116th Street–Columbia University station','The board says the train is arriving. The tunnel says absolutely nothing. At this point, I am in a long-distance relationship with the 1 train.','60000000-0000-4000-8000-000000000002',true) on conflict(id) do nothing;
insert into public.ai_generations(id,prompt,system_prompt,title,body,language,provider) values('60000000-0000-4000-8000-000000000003','做成吐槽平台 并自拟一些文案先添加上去
只有用户登录后才有上传吐槽，点赞/踩的权限
吐槽上传界面可以选择添加文字或者文字和照片一起（吐槽格式：标题 地点（位置） 正文 和照片）
并且可以对别人已上传的内容进行评价（用户可以在主页通过点击吐槽进入这条吐槽的页面，包含吐槽本身（图片和文字），以及评论区） 整体的主页面不显示评论，仅显示吐槽的标题以及地点）','Codex conversation drafts; no separate generation API system prompt was supplied.','My weekend budget lost to a sandwich','I planned a cheap day exploring the city. Then I bought one sandwich and my spreadsheet quietly changed the activity to “walk home.”','en','codex') on conflict(id) do nothing;
insert into public.rants(id,title,location,body,generation_id,is_example) values('70000000-0000-4000-8000-000000000003','My weekend budget lost to a sandwich','Morningside Heights','I planned a cheap day exploring the city. Then I bought one sandwich and my spreadsheet quietly changed the activity to “walk home.”','60000000-0000-4000-8000-000000000003',true) on conflict(id) do nothing;
insert into public.ai_generations(id,prompt,system_prompt,title,body,language,provider) values('60000000-0000-4000-8000-000000000004','做成吐槽平台 并自拟一些文案先添加上去
只有用户登录后才有上传吐槽，点赞/踩的权限
吐槽上传界面可以选择添加文字或者文字和照片一起（吐槽格式：标题 地点（位置） 正文 和照片）
并且可以对别人已上传的内容进行评价（用户可以在主页通过点击吐槽进入这条吐槽的页面，包含吐槽本身（图片和文字），以及评论区） 整体的主页面不显示评论，仅显示吐槽的标题以及地点）','Codex conversation drafts; no separate generation API system prompt was supplied.','A quiet floor with a podcast guest','Someone three tables away is explaining their entire group project on speakerphone. Glad the assignment is collaborative. Apparently, so is my study session.','en','codex') on conflict(id) do nothing;
insert into public.rants(id,title,location,body,generation_id,is_example) values('70000000-0000-4000-8000-000000000004','A quiet floor with a podcast guest','Butler Library','Someone three tables away is explaining their entire group project on speakerphone. Glad the assignment is collaborative. Apparently, so is my study session.','60000000-0000-4000-8000-000000000004',true) on conflict(id) do nothing;
insert into public.ai_generations(id,prompt,system_prompt,title,body,language,provider) values('60000000-0000-4000-8000-000000000005','做成吐槽平台 并自拟一些文案先添加上去
只有用户登录后才有上传吐槽，点赞/踩的权限
吐槽上传界面可以选择添加文字或者文字和照片一起（吐槽格式：标题 地点（位置） 正文 和照片）
并且可以对别人已上传的内容进行评价（用户可以在主页通过点击吐槽进入这条吐槽的页面，包含吐槽本身（图片和文字），以及评论区） 整体的主页面不显示评论，仅显示吐槽的标题以及地点）','Codex conversation drafts; no separate generation API system prompt was supplied.','The dorm kitchen has one permanent resident','There is a pan in the sink that has been here longer than some friendships. I do not know who owns it, but it should probably start paying housing fees.','en','codex') on conflict(id) do nothing;
insert into public.rants(id,title,location,body,generation_id,is_example) values('70000000-0000-4000-8000-000000000005','The dorm kitchen has one permanent resident','Residence hall kitchen','There is a pan in the sink that has been here longer than some friendships. I do not know who owns it, but it should probably start paying housing fees.','60000000-0000-4000-8000-000000000005',true) on conflict(id) do nothing;
insert into public.ai_generations(id,prompt,system_prompt,title,body,language,provider) values('60000000-0000-4000-8000-000000000006','做成吐槽平台 并自拟一些文案先添加上去
只有用户登录后才有上传吐槽，点赞/踩的权限
吐槽上传界面可以选择添加文字或者文字和照片一起（吐槽格式：标题 地点（位置） 正文 和照片）
并且可以对别人已上传的内容进行评价（用户可以在主页通过点击吐槽进入这条吐槽的页面，包含吐槽本身（图片和文字），以及评论区） 整体的主页面不显示评论，仅显示吐槽的标题以及地点）','Codex conversation drafts; no separate generation API system prompt was supplied.','New York walking speed is a placement exam','Back home, a walk was a walk. Here, stopping for half a second makes me the final boss of pedestrian traffic. I am learning, please allow one business day.','en','codex') on conflict(id) do nothing;
insert into public.rants(id,title,location,body,generation_id,is_example) values('70000000-0000-4000-8000-000000000006','New York walking speed is a placement exam','Midtown Manhattan','Back home, a walk was a walk. Here, stopping for half a second makes me the final boss of pedestrian traffic. I am learning, please allow one business day.','60000000-0000-4000-8000-000000000006',true) on conflict(id) do nothing;
commit;
