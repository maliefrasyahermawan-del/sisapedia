import '../../data/models/submission_model.dart';

bool isValidTransition(SubmissionStatus from, SubmissionStatus to) =>
    switch ((from, to)) {
      (SubmissionStatus.submitted, SubmissionStatus.matching) => true,
      (SubmissionStatus.matching, SubmissionStatus.offered) ||
      (SubmissionStatus.matching, SubmissionStatus.cancelled) => true,
      (SubmissionStatus.offered, SubmissionStatus.accepted) ||
      (SubmissionStatus.offered, SubmissionStatus.rejected) ||
      (SubmissionStatus.offered, SubmissionStatus.expired) ||
      (SubmissionStatus.offered, SubmissionStatus.cancelled) => true,
      (SubmissionStatus.accepted, SubmissionStatus.enRoute) ||
      (SubmissionStatus.accepted, SubmissionStatus.cancelled) => true,
      (SubmissionStatus.enRoute, SubmissionStatus.weighed) => true,
      (SubmissionStatus.weighed, SubmissionStatus.completed) ||
      (SubmissionStatus.weighed, SubmissionStatus.disputed) => true,
      (SubmissionStatus.disputed, SubmissionStatus.completed) => true,
      _ => false,
    };
