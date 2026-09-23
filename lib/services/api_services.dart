import '../models/models.dart';
import 'api_client.dart';

/// 职位 / 企业 / 简历 / 投递接口（除注册登录外均需 token）。
class ApiServices {
  final ApiClient api;
  ApiServices(this.api);

  // ---------- 企业 ----------

  Future<Company> myCompany(String token) async {
    final data = await api.request('GET', '/companies/mine', token: token);
    return Company.fromJson(data as Map<String, dynamic>);
  }

  Future<Company> getCompany(String id, String token) async {
    final data = await api.request('GET', '/companies/$id', token: token);
    return Company.fromJson(data as Map<String, dynamic>);
  }

  // ---------- 职位 ----------

  Future<Paged<JobView>> searchJobs(
    String token, {
    String? keyword,
    String? location,
    String? jobType,
    int? salaryMin,
    int? salaryMax,
    int page = 1,
    int pageSize = 20,
  }) async {
    final data = await api.request(
      'GET',
      '/jobs',
      token: token,
      query: {
        if (keyword != null && keyword.isNotEmpty) 'keyword': keyword,
        if (location != null && location.isNotEmpty) 'location': location,
        'jobType': ?jobType,
        'salaryMin': ?salaryMin,
        'salaryMax': ?salaryMax,
        'page': page,
        'pageSize': pageSize,
      },
    );
    return Paged.fromJson(data as Map<String, dynamic>, JobView.fromJson);
  }

  Future<Paged<JobView>> myJobs(
    String token, {
    int page = 1,
    int pageSize = 20,
  }) async {
    final data = await api.request(
      'GET',
      '/jobs/my',
      token: token,
      query: {'page': page, 'pageSize': pageSize},
    );
    return Paged.fromJson(data as Map<String, dynamic>, JobView.fromJson);
  }

  Future<Paged<JobView>> savedJobs(
    String token, {
    int page = 1,
    int pageSize = 20,
  }) async {
    final data = await api.request(
      'GET',
      '/saved-jobs',
      token: token,
      query: {'page': page, 'pageSize': pageSize},
    );
    return Paged.fromJson(data as Map<String, dynamic>, JobView.fromJson);
  }

  Future<JobView> getJob(String id, String token) async {
    final data = await api.request('GET', '/jobs/$id', token: token);
    return JobView.fromJson(data as Map<String, dynamic>);
  }

  Future<JobView> createJob(JobWrite job, String token) async {
    final data = await api.request(
      'POST',
      '/jobs',
      token: token,
      body: job.toJson(),
    );
    return JobView.fromJson(data as Map<String, dynamic>);
  }

  Future<JobView> updateJob(String id, JobWrite job, String token) async {
    final data = await api.request(
      'PUT',
      '/jobs/$id',
      token: token,
      body: job.toJson(),
    );
    return JobView.fromJson(data as Map<String, dynamic>);
  }

  Future<void> deleteJob(String id, String token) async {
    await api.request('DELETE', '/jobs/$id', token: token);
  }

  Future<JobView> setJobActive(String id, bool active, String token) async {
    final data = await api.request(
      'POST',
      '/jobs/$id/active',
      token: token,
      body: {'isActive': active},
    );
    return JobView.fromJson(data as Map<String, dynamic>);
  }

  Future<void> saveJob(String id, String token) async {
    await api.request('POST', '/jobs/$id/save', token: token);
  }

  Future<void> unsaveJob(String id, String token) async {
    await api.request('POST', '/jobs/$id/unsave', token: token);
  }

  // ---------- 简历 ----------

  Future<List<Resume>> myResumes(String token) async {
    final data = await api.request('GET', '/resumes', token: token);
    return (data as List<dynamic>)
        .map((e) => Resume.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Resume> getResume(String id, String token) async {
    final data = await api.request('GET', '/resumes/$id', token: token);
    return Resume.fromJson(data as Map<String, dynamic>);
  }

  Future<Resume> createResume(ResumeWrite r, String token) async {
    final data = await api.request(
      'POST',
      '/resumes',
      token: token,
      body: r.toJson(),
    );
    return Resume.fromJson(data as Map<String, dynamic>);
  }

  Future<Resume> updateResume(String id, ResumeWrite r, String token) async {
    final data = await api.request(
      'PUT',
      '/resumes/$id',
      token: token,
      body: r.toJson(),
    );
    return Resume.fromJson(data as Map<String, dynamic>);
  }

  Future<void> deleteResume(String id, String token) async {
    await api.request('DELETE', '/resumes/$id', token: token);
  }

  Future<Paged<Resume>> searchResumes(
    String token, {
    String? keyword,
    int page = 1,
    int pageSize = 20,
  }) async {
    final data = await api.request(
      'GET',
      '/resumes/search',
      token: token,
      query: {
        if (keyword != null && keyword.isNotEmpty) 'keyword': keyword,
        'page': page,
        'pageSize': pageSize,
      },
    );
    return Paged.fromJson(data as Map<String, dynamic>, Resume.fromJson);
  }

  // ---------- 投递 ----------

  Future<ApplicationView> applyJob(
    String jobId,
    String token, {
    String? resumeId,
    String? coverLetter,
  }) async {
    final data = await api.request(
      'POST',
      '/jobs/$jobId/apply',
      token: token,
      body: {
        'resumeId': ?resumeId,
        if (coverLetter != null && coverLetter.isNotEmpty)
          'coverLetter': coverLetter,
      },
    );
    return ApplicationView.fromJson(data as Map<String, dynamic>);
  }

  Future<Paged<ApplicationView>> listApplications(
    String token, {
    String? jobId,
    String? status,
    int page = 1,
    int pageSize = 20,
  }) async {
    final data = await api.request(
      'GET',
      '/applications',
      token: token,
      query: {
        'jobId': ?jobId,
        if (status != null && status.isNotEmpty) 'status': status,
        'page': page,
        'pageSize': pageSize,
      },
    );
    return Paged.fromJson(
      data as Map<String, dynamic>,
      ApplicationView.fromJson,
    );
  }

  Future<ApplicationView> getApplication(String id, String token) async {
    final data = await api.request('GET', '/applications/$id', token: token);
    return ApplicationView.fromJson(data as Map<String, dynamic>);
  }

  Future<ApplicationView> setApplicationStatus(
    String id,
    String status,
    String token,
  ) async {
    final data = await api.request(
      'POST',
      '/applications/$id/status',
      token: token,
      body: {'status': status},
    );
    return ApplicationView.fromJson(data as Map<String, dynamic>);
  }

  // ---------- 线上面试 ----------

  Future<InterviewView> createInterview({
    required String applicationId,
    DateTime? scheduledAt,
    required String token,
  }) async {
    final data = await api.request(
      'POST',
      '/interviews',
      token: token,
      body: {
        'applicationId': applicationId,
        'scheduledAt': scheduledAt?.toUtc().toIso8601String(),
      },
    );
    return InterviewView.fromJson(data as Map<String, dynamic>);
  }

  Future<List<InterviewView>> myInterviews(String token) async {
    final data = await api.request('GET', '/interviews', token: token);
    return (data as List<dynamic>)
        .map((e) => InterviewView.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<InterviewView> getInterview(String id, String token) async {
    final data = await api.request('GET', '/interviews/$id', token: token);
    return InterviewView.fromJson(data as Map<String, dynamic>);
  }

  Future<InterviewView> startInterview(String id, String token) async {
    final data = await api.request(
      'POST',
      '/interviews/$id/start',
      token: token,
    );
    return InterviewView.fromJson(data as Map<String, dynamic>);
  }

  Future<InterviewView> finishInterview(String id, String token) async {
    final data = await api.request(
      'POST',
      '/interviews/$id/finish',
      token: token,
    );
    return InterviewView.fromJson(data as Map<String, dynamic>);
  }

  Future<InterviewView> cancelInterview(String id, String token) async {
    final data = await api.request(
      'POST',
      '/interviews/$id/cancel',
      token: token,
    );
    return InterviewView.fromJson(data as Map<String, dynamic>);
  }

  // ---------- 投诉 ----------

  Future<ComplaintView> createComplaint({
    required String companyId,
    required String evidence,
    required String token,
  }) async {
    final data = await api.request(
      'POST',
      '/companies/$companyId/complaints',
      token: token,
      body: {'evidence': evidence},
    );
    return ComplaintView.fromJson(data as Map<String, dynamic>);
  }

  /// 角色化列表：求职者=我的投诉；招聘者=本企业投诉；admin=全部
  Future<List<ComplaintView>> complaints(String token, {String? status}) async {
    final data = await api.request(
      'GET',
      '/complaints',
      token: token,
      query: {if (status != null && status.isNotEmpty) 'status': status},
    );
    return (data as List<dynamic>)
        .map((e) => ComplaintView.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<ComplaintView> reviewComplaint(
    String id, {
    required bool approved,
    String? note,
    required String token,
  }) async {
    final data = await api.request(
      'POST',
      '/complaints/$id/review',
      token: token,
      body: {
        'approved': approved,
        if (note != null && note.isNotEmpty) 'note': note,
      },
    );
    return ComplaintView.fromJson(data as Map<String, dynamic>);
  }
}
